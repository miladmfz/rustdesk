import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("prepare", Path(__file__).with_name("prepare-kowsardesk.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="Kowsar package ")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        for name in ("rustdesk.exe", "librustdesk.dll", "flutter_windows.dll"):
            (self.folder / name).write_bytes(name.encode())

    def test_branded_entry_point_preserves_binary_and_dependencies(self):
        result = module.prepare(self.folder)
        self.assertEqual(result.name, "KowsarDesk.exe")
        self.assertEqual(result.read_bytes(), b"rustdesk.exe")
        self.assertFalse((self.folder / "rustdesk.exe").exists())
        self.assertEqual((self.folder / "librustdesk.dll").read_bytes(), b"librustdesk.dll")

    def test_missing_native_library_leaves_original_intact(self):
        (self.folder / "librustdesk.dll").unlink()
        with self.assertRaises(FileNotFoundError):
            module.prepare(self.folder)
        self.assertTrue((self.folder / "rustdesk.exe").exists())

    def test_missing_flutter_library_is_rejected(self):
        (self.folder / "flutter_windows.dll").unlink()
        with self.assertRaises(FileNotFoundError):
            module.prepare(self.folder)

    def test_existing_branded_binary_is_not_overwritten(self):
        target = self.folder / "KowsarDesk.exe"
        target.write_bytes(b"previous build")
        with self.assertRaises(FileExistsError):
            module.prepare(self.folder)
        self.assertEqual(target.read_bytes(), b"previous build")

    def test_missing_executable_is_rejected(self):
        (self.folder / "rustdesk.exe").unlink()
        with self.assertRaises(FileNotFoundError):
            module.prepare(self.folder)


if __name__ == "__main__":
    unittest.main()
