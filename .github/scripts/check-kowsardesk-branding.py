"""Verify committed branding assets before compilation, without image dependencies."""
import hashlib,json,struct
from pathlib import Path
root=Path(__file__).resolve().parents[2]
m=json.loads((root/'res/branding/manifest.json').read_text())
assert hashlib.sha256((root/'res/branding/kowsardesk-master.png').read_bytes()).hexdigest()==m['master_sha256']
for name,info in m['assets'].items():
 data=(root/name).read_bytes()
 assert hashlib.sha256(data).hexdigest()==info['sha256'],f'Branding asset modified: {name}'
 if name.endswith('.png'):
  assert data[:8]==b'\x89PNG\r\n\x1a\n'
  assert list(struct.unpack('>II',data[16:24]))==info['size'],name
 if name.endswith('.ico'):
  reserved,kind,count=struct.unpack_from('<HHH',data)
  assert reserved==0 and kind==1
  sizes={data[6+16*i] or 256 for i in range(count)}
  assert sizes==set(info['ico_sizes']),name
assert (root/'res/icon.ico').read_bytes()==(root/'flutter/windows/runner/resources/app_icon.ico').read_bytes()
assert (root/'res/tray-icon.ico').read_bytes()==(root/'res/icon.ico').read_bytes()
print(f'PASS: {len(m["assets"])} brand assets, PNG dimensions and multi-resolution Windows icons verified')
