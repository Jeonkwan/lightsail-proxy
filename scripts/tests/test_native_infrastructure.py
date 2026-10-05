"""Reject unsafe replacement plans before any Terraform apply."""
import contextlib, importlib.util, io, json, os, pathlib, unittest
from unittest.mock import patch

path = pathlib.Path(__file__).resolve().parents[1] / 'native-infrastructure.py'
spec = importlib.util.spec_from_file_location('native_infrastructure', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
OLD = 'lightsail-singapore-c-decaf-old'
NEW = 'lightsail-singapore-c-decaf-new'
PEER = 'lightsail-singapore-a-flatwhite-peer'

class ReplacementGuards(unittest.TestCase):
    def exercise(self, unsafe=None):
        state = {'resources': [{'type': 'aws_lightsail_instance',
                  'instances': [{'attributes': {'name': OLD}}]}]}
        plan = {'resource_changes': [
            {'address': 'aws_lightsail_instance.lightsail_instance',
             'type': 'aws_lightsail_instance', 'change': {
                 'actions': ['delete', 'create'], 'before': {'name': OLD},
                 'after': {'name': NEW, 'availability_zone': 'ap-southeast-1c',
                           'blueprint_id': 'ubuntu_24_04'}}},
            {'address': 'aws_lightsail_static_ip.instance_ip',
             'type': 'aws_lightsail_static_ip', 'change': {
                 'actions': ['no-op'], 'before': {'name': 'lightsail-singapore-c-decaf-ip'},
                 'after': {'name': 'lightsail-singapore-c-decaf-ip'}}}]}
        if unsafe == 'peer':
            plan['resource_changes'][0]['change']['before']['name'] = PEER
        if unsafe == 'static_ip':
            plan['resource_changes'][1]['change']['actions'] = ['delete', 'create']
        if unsafe == 'workspace':
            state['resources'][0]['instances'][0]['attributes']['name'] = PEER
        peer = {'name': PEER, 'publicIpAddress': '192.0.2.1'}
        selected = {'name': OLD, 'publicIpAddress': '192.0.2.2',
                    'location': {'availabilityZone': 'ap-southeast-1c'}}
        inventories = iter([[selected, peer], [{**selected, 'name': NEW}, peer]])
        def aws(*args):
            if args == ('get-instances',): return {'instances': next(inventories)}
            if args == ('get-instance-snapshots',): return {'instanceSnapshots': []}
            raise AssertionError(args)
        def call(*args):
            if args == ('terraform', 'workspace', 'list'): return 'default decaf flatwhite'
            if args == ('terraform', 'state', 'pull'): return json.dumps(state)
            if args[:3] == ('terraform', 'show', '-json'): return json.dumps(plan)
            raise AssertionError(args)
        env = {'TARGET': 'decaf', 'OPERATION': 'replace', 'EXPECTED_INSTANCE': OLD,
               'TF_BACKEND_BUCKET': 'test', 'TF_BACKEND_KEY': 'test',
               'TF_BACKEND_REGION': 'ap-southeast-1', 'RUNNER_TEMP': '/tmp'}
        with patch.dict(os.environ, env, clear=True), patch.object(module, 'aws', aws), \
             patch.object(module, 'call', call), patch.object(module, 'tf') as tf, \
             contextlib.redirect_stdout(io.StringIO()):
            if unsafe:
                with self.assertRaises(AssertionError): module.main()
                self.assertFalse(any(c.args[0] == 'apply' for c in tf.call_args_list))
            else:
                module.main()
                self.assertEqual(os.environ['TF_VAR_selected_zone'], 'c')
                self.assertTrue(any(c.args[0] == 'apply' for c in tf.call_args_list))

    def test_decaf_zone_c_replacement(self): self.exercise()
    def test_reject_peer_instance_plan(self): self.exercise('peer')
    def test_reject_static_ip_replacement(self): self.exercise('static_ip')
    def test_reject_wrong_workspace_owner(self): self.exercise('workspace')

class SpareGuards(unittest.TestCase):
    def test_spare_workflow_rejects_serving_targets_before_aws(self):
        with patch.dict(os.environ, {'TARGET':'flatwhite','OPERATION':'destroy','SPARE_ONLY':'true'}, clear=True), patch.object(module,'aws') as aws:
            with self.assertRaisesRegex(AssertionError,'serving target'): module.main()
            aws.assert_not_called()

    def test_spare_create_is_isolated_and_never_sets_ddns_secret(self):
        for target,zone in [('americano','a'),('latte','c')]:
            with self.subTest(target=target):
                prefix='lightsail-singapore-'+zone+'-'+target
                peer={'name':PEER,'publicIpAddress':'192.0.2.1'}
                spare={'name':prefix+'-new','publicIpAddress':'192.0.2.2'}
                inventories=iter([[peer],[peer,spare]])
                plan={'resource_changes':[{'address':'aws_lightsail_instance.lightsail_instance','type':'aws_lightsail_instance','change':{'actions':['create'],'before':None,'after':{'availability_zone':'ap-southeast-1'+zone,'blueprint_id':'ubuntu_24_04'}}}]}
                def aws(*args):
                    if args==('get-instances',):return {'instances':next(inventories)}
                    if args==('get-static-ips',):return {'staticIps':[]}
                    if args==('get-key-pairs',):return {'keyPairs':[]}
                    raise AssertionError(args)
                def call(*args):
                    if args==('terraform','workspace','list'):return 'default flatwhite decaf'
                    if args==('terraform','state','list'):return ''
                    if args[:3]==('terraform','show','-json'):return json.dumps(plan)
                    raise AssertionError(args)
                env={'TARGET':target,'OPERATION':'create','SPARE_ONLY':'true','TF_VAR_namecheap_ddns_password':'must-not-be-used','TF_BACKEND_BUCKET':'test','TF_BACKEND_KEY':'test','TF_BACKEND_REGION':'ap-southeast-1','RUNNER_TEMP':'/tmp'}
                with patch.dict(os.environ,env,clear=True),patch.object(module,'aws',aws),patch.object(module,'call',call),patch.object(module,'tf') as tf,contextlib.redirect_stdout(io.StringIO()):
                    module.main()
                    self.assertEqual(os.environ['TF_VAR_namecheap_ddns_password'],'')
                    self.assertEqual(os.environ['TF_VAR_selected_zone'],zone)
                    self.assertTrue(any(c.args[0]=='apply' for c in tf.call_args_list))

if __name__ == '__main__': unittest.main()
