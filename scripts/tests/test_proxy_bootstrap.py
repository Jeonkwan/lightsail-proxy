"""Exercise first boot, resume, and failed reboot guards without host mutations."""
from pathlib import Path
import tempfile,subprocess,os,json
root=Path(__file__).resolve().parents[2]
values={name:"" for name in ["username","domain_name","subdomain_name","public_ip","namecheap_ddns_password","proxy_server_uuid","playbook_branch","proxy_solution","proxy_contact_email","less_vision_reality_short_ids","less_vision_reality_private_key","less_vision_reality_public_key","less_vision_reality_decoy_domain"]}
values.update(username="ubuntu",proxy_solution="basic-vm",playbook_branch="feature/selectable-xray-runtime")
expression="templatefile("+json.dumps(str(root/"scripts/cloud-init/setup_ubuntu.sh.tftpl"))+", jsondecode("+json.dumps(json.dumps(values))+"))\n"
with tempfile.TemporaryDirectory() as console_dir:
 rendered=subprocess.check_output(["terraform","console"],input=expression,text=True,cwd=console_dir).strip()
 if rendered.startswith("<<"):
  marker=rendered.splitlines()[0][2:]
  assert rendered.endswith("\n"+marker)
  source=rendered[rendered.index("\n")+1:-(len(marker)+1)]
 else:
  source=json.loads(rendered)
subprocess.run(["sh","-n"],input=source,text=True,check=True)
for case in ('first','resume','resume_missing','failed'):
 with tempfile.TemporaryDirectory() as td:
  root=Path(td); cmd=root/'cmd';cmd.mkdir(); log=root/'commands'
  for name in ('fallocate','chmod','mkswap','swapon','systemctl','update-grub','shutdown','apt-get','uname','snap'):
   p=cmd/name;p.write_text('#!/bin/sh\nprintf "%s\\n" "'+name+' $*" >> "$TEST_LOG"\n');p.chmod(0o755)
  if case=='resume_missing':
   p=cmd/'dpkg-query';p.write_text('#!/bin/sh\n[ \"$3\" = python3 ] && exit 1\necho \"install ok installed\"\n');p.chmod(0o755)
  boot=root/'var/lib/proxy-bootstrap';boot.mkdir(parents=True)
  (root/'proc').mkdir();(root/'proc/cmdline').write_text('console=ttyS0 '+('kho=off' if case.startswith('resume') else ''))
  if case=='failed':(boot/'reboot-requested').touch()
  (root/'etc/systemd/system').mkdir(parents=True);(root/'etc/fstab').touch();(root/'swapfile').touch()
  # All absolute deployment destinations point into the isolated test root.
  script=source
  import re
  script=re.sub(r'(?<![\w])/(?:etc|var/lib/proxy-bootstrap|opt|swapfile|proc/cmdline)(?=/|\b)',lambda m:td+m.group(),source)
  script=script.replace('while fuser ','while false ')
  f=root/'setup.sh';f.write_text(script)
  env={**os.environ,'PATH':str(cmd)+':'+os.environ['PATH'],'TEST_LOG':str(log)}
  r=subprocess.run(['/bin/sh',str(f)],env=env,capture_output=True,text=True)
  lines=log.read_text() if log.exists() else ''
  if case=='first':
   assert r.returncode==0,r.stderr
   assert 'shutdown -r +1' in lines and 'apt-get' not in lines
   assert (boot/'setup.sh').exists() and (boot/'reboot-requested').exists()
   assert not (boot/'complete').exists()
   unit=(root/'etc/systemd/system/proxy-bootstrap.service').read_text()
   assert 'WantedBy=cloud-init.target' in unit and 'Before=cloud-init.target' in unit
   assert 'WantedBy=multi-user.target' not in unit
  elif case.startswith('resume'):
   assert r.returncode==0,r.stderr
   assert 'shutdown' not in lines
   if case=='resume_missing':
    assert 'apt-get update' in lines and 'apt-get install --no-install-recommends -y python3' in lines
   else:assert 'apt-get' not in lines
   assert 'gpg' not in lines and 'lsb-release' not in lines
   assert 'python3-pip' not in lines and 'ansible' not in lines
   assert 'docker' not in lines and 'compose' not in lines and 'curl' not in lines
   retention=(root/'etc/systemd/journald.conf.d/zz-proxy-retention.conf').read_text()
   for setting in ['Storage=persistent','SystemMaxUse=100M','RuntimeMaxUse=32M',
                   'SystemMaxFileSize=10M','MaxRetentionSec=7day','ForwardToSyslog=no']:
    assert setting in retention,setting
   assert (boot/'complete').exists()
  else:
   assert r.returncode!=0 and 'refusing a reboot loop' in r.stderr
   assert 'shutdown' not in lines
   if case=='resume_missing':
    assert 'apt-get update' in lines and 'apt-get install --no-install-recommends -y python3' in lines
   else:assert 'apt-get' not in lines
  print(case,'PASS')
