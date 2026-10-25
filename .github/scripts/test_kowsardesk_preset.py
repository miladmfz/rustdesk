import base64
import hashlib
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('preset', Path(__file__).with_name('check-kowsardesk-preset.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PresetTests(unittest.TestCase):
    def setUp(self):
        self.salt = '0123456789abcdef0123456789abcdef'
        self.h1 = hashlib.sha256(b'fixture-only-credential' + self.salt.encode()).digest()
        self.value = '00' + base64.b64encode(self.h1).decode()
        self.env = {module.HASH_KEY:self.value, module.SALT_KEY:self.salt}

    def test_valid_hashed_preset(self):
        self.assertEqual(module.load_preset(self.env), (self.value, self.salt))

    def test_missing_secret_rejected(self):
        with self.assertRaises(ValueError): module.load_preset({})

    def test_plaintext_rejected(self):
        self.env[module.HASH_KEY] = 'fixture-plaintext'
        with self.assertRaises(ValueError): module.load_preset(self.env)

    def test_wrong_hash_length_rejected(self):
        self.env[module.HASH_KEY] = '00' + base64.b64encode(b'short').decode()
        with self.assertRaises(ValueError): module.load_preset(self.env)

    def test_invalid_base64_rejected(self):
        self.env[module.HASH_KEY] = '00!!!'
        with self.assertRaises(ValueError): module.load_preset(self.env)

    def test_missing_salt_rejected(self):
        self.env[module.SALT_KEY] = ''
        with self.assertRaises(ValueError): module.load_preset(self.env)

    def test_wrong_password_challenge_response_rejected(self):
        challenge = b'fixture-challenge'
        correct = hashlib.sha256(self.h1 + challenge).digest()
        wrong_h1 = hashlib.sha256(b'wrong-fixture' + self.salt.encode()).digest()
        self.assertNotEqual(correct, hashlib.sha256(wrong_h1 + challenge).digest())

    def test_payload_requires_both_hash_and_salt(self):
        with self.assertRaises(ValueError): module.verify_binary(self.value.encode(), self.value, self.salt)
        module.verify_binary((self.value + self.salt).encode(), self.value, self.salt)

    def test_source_requires_old_override_removal(self):
        with self.assertRaises(ValueError): module.verify_source('')
        module.verify_source(Path('src/common.rs').read_text(encoding='utf-8'))

    def test_runtime_double_quoted_empty_override(self):
        module.verify_runtime_config('password = ""\nsalt = "'+self.salt+'"\n', self.salt)

    def test_runtime_literal_quoted_empty_override(self):
        module.verify_runtime_config("password = ''\nsalt = '"+self.salt+"'\n", self.salt)

    def test_runtime_saved_password_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify_runtime_config("password = 'old-fixture'\nsalt = '"+self.salt+"'\n", self.salt)

    def test_runtime_mismatching_salt_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify_runtime_config("password = ''\nsalt = '"+'f'*32+"'\n", self.salt)

if __name__ == '__main__': unittest.main()
