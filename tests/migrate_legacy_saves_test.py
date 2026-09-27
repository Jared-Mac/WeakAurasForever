"""Exercise real file copies without evaluating Lua or touching WoW saves."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'migration', Path(__file__).resolve().parents[1] / 'tools/migrate_legacy_saves.py')
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class MigrationTest(unittest.TestCase):
    def test_preserves_payload_and_all_three_sources(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for source, old, target, new in migration.SAVES:
                payload = (b'\r\n' + old.encode() + b' = {\r\n'
                           b'["custom"] = "WeakAurasSaved = {} -- do not rewrite",\r\n'
                           b'["displays"] = {}, ["enabled"] = false,\r\n}\r\n')
                (root / (source + '.lua')).write_bytes(payload)
            plan, _ = migration.migration_plan(root)
            self.assertEqual(len(plan), 3)
            self.assertFalse((root / 'WAF.lua').exists(), 'preview must not write')
            migration.apply_plan(plan)
            for (_, old, _, new), (source, target, original, _) in zip(migration.SAVES, plan):
                self.assertEqual(source.read_bytes(), original)
                self.assertEqual(target.read_bytes(), original.replace(old.encode(), new.encode(), 1))
            self.assertEqual(migration.migration_plan(root)[0], [], 'repeat must be a no-op')

    def test_existing_files_win_even_if_empty(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for content in (b'', b'WAFSaved = {}', b'WAFSaved = {displays={}}'):
                (root / 'WAF.lua').write_bytes(content)
                (root / 'WeakAuras.lua').write_bytes(b'WeakAurasSaved = {displays={old={}}}')
                plan, _ = migration.migration_plan(root)
                migration.apply_plan(plan)
                self.assertEqual((root / 'WAF.lua').read_bytes(), content)

    def test_invalid_source_refuses_entire_plan(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'WeakAuras.lua').write_bytes(b'WeakAurasSaved = {}')
            (root / 'WeakAurasOptions.lua').write_bytes(b'print("not saved data")')
            with self.assertRaises(ValueError):
                migration.migration_plan(root)
            self.assertFalse((root / 'WAF.lua').exists())

    def test_changed_source_and_new_target_are_not_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source, target = root / 'WeakAuras.lua', root / 'WAF.lua'
            source.write_bytes(b'WeakAurasSaved = {}')
            plan, _ = migration.migration_plan(root)
            source.write_bytes(b'WeakAurasSaved = {new=true}')
            with self.assertRaises(ValueError):
                migration.apply_plan(plan)
            self.assertFalse(target.exists())
            plan, _ = migration.migration_plan(root)
            target.write_bytes(b'WAFSaved = {}')
            with self.assertRaises(FileExistsError):
                migration.apply_plan(plan)
            self.assertEqual(target.read_bytes(), b'WAFSaved = {}')


if __name__ == '__main__':
    unittest.main()
