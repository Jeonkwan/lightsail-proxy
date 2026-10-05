#!/usr/bin/env python3
"""Guard selected Cream/Flat White resources; preserve every other instance."""
import json,os,pathlib,subprocess,time

def call(*cmd):return subprocess.check_output(cmd,text=True).strip()
def aws(*args):return json.loads(call('aws','lightsail',*args,'--region','ap-southeast-1'))
def tf(*args):subprocess.run(['terraform',*args],check=True)
def main():
 target=os.environ['TARGET'];op=os.environ['OPERATION'];expected=os.environ.get('EXPECTED_INSTANCE','')
 assert target in ['cream','flatwhite'] and op in ['inspect','create','replace','destroy']
 os.environ.pop('TF_WORKSPACE',None)
 # Workspace-specific bootstrap variables must never redirect this operation.
 for k,v in {'instance_customizable_name':target,'subdomain_name':target,'selected_country':'singapore','selected_zone':'a','domain_name':'mokamaker.site','proxy_solution':'basic-vm','playbook_branch':'feature/native-xray'}.items():os.environ['TF_VAR_'+k]=v
 prefix='lightsail-singapore-a-'+target
 before=aws('get-instances')['instances'];selected=[x for x in before if x['name'].startswith(prefix+'-')]
 protected={x['name']:x['publicIpAddress'] for x in before if x not in selected}
 print('Instances:',json.dumps([{k:x.get(k) for k in ['name','publicIpAddress','state','blueprintId']} for x in before]),flush=True)
 tf('init','-input=false','-backend-config=bucket='+os.environ['TF_BACKEND_BUCKET'],'-backend-config=key='+os.environ['TF_BACKEND_KEY'],'-backend-config=region='+os.environ['TF_BACKEND_REGION'])
 workspaces=call('terraform','workspace','list').replace('*','').split()
 if op=='inspect':
  if target in workspaces:
   tf('workspace','select',target);print('Selected state addresses:',call('terraform','state','list'))
  print('Static IPs:',json.dumps(aws('get-static-ips')['staticIps']))
  print('Snapshots:',json.dumps([{'name':x['name'],'fromInstanceName':x.get('fromInstanceName')} for x in aws('get-instance-snapshots')['instanceSnapshots']]))
  return
 if op=='create':
  assert not selected,'Target instance already exists; clean it first'
  assert not any(x['name']==prefix+'-ip' for x in aws('get-static-ips')['staticIps']),'Static IP remains'
  assert not any(x['name']=='key-'+prefix for x in aws('get-key-pairs')['keyPairs']),'Key pair remains'
  tf('workspace','select','-or-create',target);assert not call('terraform','state','list'),'Workspace is not empty'
 else:
  assert len(selected)==1 and selected[0]['name']==expected,'Exact selected identity must match'
  assert selected[0]['location']['availabilityZone']=='ap-southeast-1a'
  tf('workspace','select',target)
  state=json.loads(call('terraform','state','pull'))
  instances=[i['attributes']['name'] for r in state['resources'] if r['type']=='aws_lightsail_instance' for i in r['instances']]
  assert instances==[expected],'Workspace does not own selected instance'
 args=['plan','-input=false','-out='+os.environ['RUNNER_TEMP']+'/native.tfplan']
 if op=='destroy':args+=['-destroy']
 if op=='replace':args+=['-replace=aws_lightsail_instance.lightsail_instance']
 tf(*args)
 plan=json.loads(call('terraform','show','-json',os.environ['RUNNER_TEMP']+'/native.tfplan'))
 changes=plan.get('resource_changes',[]);allowed={'aws_lightsail_instance','aws_lightsail_static_ip','aws_lightsail_static_ip_attachment','aws_lightsail_instance_public_ports','aws_lightsail_key_pair','null_resource'}
 assert changes
 for r in changes:
  assert r['type'] in allowed;actions=r['change']['actions'];old=r['change'].get('before') or {};new=r['change'].get('after') or {}
  if actions==['no-op']:continue
  if op=='create':assert actions==['create']
  if op=='destroy':assert actions==['delete']
  if op=='replace' and r['type'] in ['aws_lightsail_static_ip','aws_lightsail_key_pair','null_resource']:raise AssertionError('Replacement must preserve static IP, key pair and DNS')
  if r['type']=='aws_lightsail_instance':
   if op!='create':assert old['name']==expected
   if op!='destroy':assert new['availability_zone']=='ap-southeast-1a' and new['blueprint_id']=='ubuntu_24_04'
  elif r['type']=='aws_lightsail_static_ip':assert (old or new)['name']==prefix+'-ip'
  elif r['type']=='aws_lightsail_key_pair':assert (old or new)['name']=='key-'+prefix
  elif r['type'] in ['aws_lightsail_static_ip_attachment','aws_lightsail_instance_public_ports'] and op!='create':assert old['instance_name']==expected
  elif r['type']=='null_resource':assert (old or new)['triggers']['subdomain']==target
  print('Verified resource:',r['address'],actions,flush=True)
 tf('apply','-input=false',os.environ['RUNNER_TEMP']+'/native.tfplan')
 after=aws('get-instances')['instances'];actual={x['name']:x['publicIpAddress'] for x in after}
 assert all(actual.get(k)==v for k,v in protected.items()),'Protected instance changed'
 if op=='destroy':
  assert not any(x['name'].startswith(prefix+'-') for x in after)
  for snapshot in aws('get-instance-snapshots')['instanceSnapshots']:
   if snapshot.get('fromInstanceName')==expected:subprocess.run(['aws','lightsail','delete-instance-snapshot','--instance-snapshot-name',snapshot['name'],'--region','ap-southeast-1'],check=True)
  assert not call('terraform','state','list');tf('workspace','select','default');tf('workspace','delete',target)
  # Park the retired client-configured hostname with no serving address.
  import urllib.parse,urllib.request
  query=urllib.parse.urlencode({'host':target,'domain':'mokamaker.site','password':os.environ['TF_VAR_namecheap_ddns_password'],'ip':'127.0.0.1'})
  with urllib.request.urlopen('https://dynamicdns.park-your-domain.com/update?'+query,timeout=30) as response:body=response.read()
  assert b'<ErrCount>0</ErrCount>' in body,'DNS parking failed'
 else:
  x=next(x for x in after if x['name'].startswith(prefix+'-'));print('Created identity:',x['name'],x['publicIpAddress'],flush=True)
 print('Preserved peers:',json.dumps(protected),flush=True)
if __name__=='__main__':main()
