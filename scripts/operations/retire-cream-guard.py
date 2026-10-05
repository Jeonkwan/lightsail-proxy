import json,subprocess,sys,time
TARGET='lightsail-singapore-a-cream-20261004151043'
IPNAME='lightsail-singapore-a-cream-ip'
KEY='key-lightsail-singapore-a-cream'
SURVIVORS={'lightsail-singapore-a-flatwhite-20261005025909':'54.179.39.30','lightsail-singapore-c-decaf-20260730010620':'52.74.81.140'}
def aws(command,*args):
    return json.loads(subprocess.check_output(['aws','lightsail',command,'--region','ap-southeast-1','--output','json',*args]))
def inventory():
    instances=aws('get-instances')['instances']
    ips=aws('get-static-ips')['staticIps']
    keys=aws('get-key-pairs')['keyPairs']
    for name,ip in SURVIVORS.items():
        matches=[i for i in instances if i['name']==name]
        assert len(matches)==1 and matches[0]['publicIpAddress']==ip and matches[0]['state']['name']=='running',name
        print('Preserved running instance:',name,ip)
    return instances,ips,keys
stage=sys.argv[1]
if stage=='plan':
    p=json.load(open('artifacts/terraform/plan.json'))
    expected={'aws_lightsail_instance','aws_lightsail_static_ip','aws_lightsail_static_ip_attachment','aws_lightsail_instance_public_ports','aws_lightsail_key_pair','null_resource'}
    changes=p.get('resource_changes',[])
    assert len(changes)==6,len(changes)
    seen=set()
    for r in changes:
        assert r['change']['actions']==['delete'],r['address']
        t=r['type'];assert t in expected;seen.add(t);b=r['change']['before']
        if t=='aws_lightsail_instance': assert b['name']==TARGET and b['availability_zone']=='ap-southeast-1a'
        elif t=='aws_lightsail_static_ip': assert b['name']==IPNAME and b['ip_address']=='13.250.199.129'
        elif t=='aws_lightsail_static_ip_attachment': assert b['instance_name']==TARGET and b['static_ip_name']==IPNAME
        elif t=='aws_lightsail_instance_public_ports': assert b['instance_name']==TARGET
        elif t=='aws_lightsail_key_pair': assert b['name']==KEY
        elif t=='null_resource': assert b['triggers']['domain']=='mokamaker.site' and b['triggers']['subdomain']=='cream'
        print('Verified Cream deletion:',r['address'])
    assert seen==expected
elif stage=='before':
    instances,ips,keys=inventory()
    t=[i for i in instances if i['name']==TARGET];assert len(t)==1
    assert t[0]['publicIpAddress']=='13.250.199.129' and t[0]['location']['availabilityZone']=='ap-southeast-1a'
    s=[i for i in ips if i['name']==IPNAME];assert len(s)==1 and s[0]['ipAddress']=='13.250.199.129' and s[0]['attachedTo']==TARGET
    assert any(i['name']==KEY for i in keys)
    snapshots=[s['name'] for s in aws('get-instance-snapshots')['instanceSnapshots'] if s.get('fromInstanceName')==TARGET]
    print('Cream snapshots to clean:',snapshots)
    open('cream-snapshots.json','w').write(json.dumps(snapshots))
    disks=[d['name'] for d in aws('get-disks')['disks'] if d.get('attachedTo')==TARGET]
    assert not disks,('Unexpected attached disks need explicit resource verification',disks)
    print('Exact target verified:',TARGET)
elif stage=='after':
    instances,ips,keys=inventory()
    assert not any(i['name']==TARGET for i in instances)
    assert not any(i['name']==IPNAME for i in ips)
    assert not any(i['name']==KEY for i in keys)
    snapshots=json.load(open('cream-snapshots.json'))
    current=aws('get-instance-snapshots')['instanceSnapshots']
    for name in snapshots:
        if any(s['name']==name and s.get('fromInstanceName')==TARGET for s in current):
            aws('delete-instance-snapshot','--instance-snapshot-name',name)
            print('Removed Cream snapshot:',name)
    for attempt in range(24):
        remaining=[s['name'] for s in aws('get-instance-snapshots')['instanceSnapshots'] if s.get('fromInstanceName')==TARGET]
        if not remaining: break
        time.sleep(5)
    assert not remaining,remaining
    print('Cream instance, static IP, key and snapshots are absent')
else: raise ValueError(stage)
