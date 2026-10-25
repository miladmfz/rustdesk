"""Validate preset inputs and verify native payloads without disclosing values."""
import base64
import os
from pathlib import Path
import re
import sys
from zipfile import ZipFile

HASH_KEY = 'KOWSARDESK_PRESET_PASSWORD_HASH'
SALT_KEY = 'KOWSARDESK_PRESET_PASSWORD_SALT'

def load_preset(env=None):
    env = os.environ if env is None else env
    value, salt = env.get(HASH_KEY, ''), env.get(SALT_KEY, '')
    try:
        valid = value.startswith('00') and len(base64.b64decode(value[2:], validate=True)) == 32
    except (ValueError, TypeError):
        valid = False
    if not valid or not re.fullmatch(r'[0-9a-f]{32}', salt):
        raise ValueError('Missing or invalid hashed preset build secrets')
    return value, salt

def verify_binary(data, value, salt):
    if value.encode() not in data or salt.encode() not in data:
        raise ValueError('Configured hashed preset is missing from native payload')

def verify_source(source):
    required = (f'option_env!("{HASH_KEY}")', f'option_env!("{SALT_KEY}")',
                'Config::set_permanent_password_storage_for_sync("", salt)',
                'OPTION_DISABLE_CHANGE_PERMANENT_PASSWORD')
    if not all(item in source for item in required):
        raise ValueError('Preset enforcement is missing from client source')
    if re.search(r'hard_settings.insert\(\s*"password".to_owned\(\),\s*"[^"\n]+".to_owned', source):
        raise ValueError('Literal credential found in client source')

if __name__ == '__main__':
    try:
        value, salt = load_preset()
        if len(sys.argv) == 1:
            verify_source(Path('src/common.rs').read_text(encoding='utf-8'))
        elif sys.argv[1] == '--apk':
            with ZipFile(sys.argv[2]) as apk:
                verify_binary(apk.read('lib/arm64-v8a/librustdesk.so'), value, salt)
        else:
            verify_binary(Path(sys.argv[1]).read_bytes(), value, salt)
        print('Hashed preset configuration verified; values withheld.')
    except (ValueError, KeyError) as error:
        raise SystemExit(str(error)) from None
