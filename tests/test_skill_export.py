import hashlib
from contextlib import closing, contextmanager
import importlib.util
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
EXPORTER = ROOT / "tools/export_skill_database.py"
SPEC = importlib.util.spec_from_file_location("skill_export", EXPORTER)
skill_export = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(skill_export)


@contextmanager
def open_database(path):
    with closing(sqlite3.connect(path)) as connection, connection:
        yield connection


class SkillExportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.database = Path(self.directory.name) / "skills.sqlite"
        self.output = Path(self.directory.name) / "skills.json"
        with open_database(self.database) as connection:
            connection.executescript((ROOT / "data/sql/skill_database.sql").read_text(encoding="utf-8-sig"))

    def run_export(self, *extra):
        return subprocess.run(
            [sys.executable, str(EXPORTER), "--database", str(self.database), "--output", str(self.output), *extra],
            capture_output=True, text=True, encoding="utf-8", check=False,
        )

    def test_positions_normalize_without_losing_the_all_columns_rule(self):
        self.assertEqual(skill_export.parse_columns("  ", 1), [1, 2, 3, 4])
        self.assertEqual(skill_export.parse_columns("4, 2,2", 1), [2, 4])
        for value in ["0", "5", "1,", "front"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                skill_export.parse_columns(value, 1)

    def test_export_preserves_authoring_data_and_null_ap(self):
        with open_database(self.database) as connection:
            connection.execute("UPDATE skills SET main_stat = ? WHERE id = 1", ("힘0.5+민첩1.0",))
        before = hashlib.sha256(self.database.read_bytes()).hexdigest()
        catalog = skill_export.read_catalog(self.database)
        self.assertEqual(hashlib.sha256(self.database.read_bytes()).hexdigest(), before)
        self.assertIsNone(catalog["skills"][0]["ap_cost"])
        self.assertEqual(catalog["skills"][0]["main_stat"], "힘0.5+민첩1.0")
        self.assertEqual(catalog["skills"][0]["usable_columns"], [2, 3, 4])
        self.assertEqual(len(catalog["jobs"]), 6)
        self.assertEqual(catalog["job_skill_unlocks"][0]["skill_id"], 1)

    def test_check_mode_detects_saved_db_changes(self):
        self.assertEqual(self.run_export().returncode, 0)
        first_export = self.output.read_bytes()
        self.assertEqual(self.run_export("--check").returncode, 0)
        self.assertEqual(self.run_export().returncode, 0)
        self.assertEqual(self.output.read_bytes(), first_export)
        with open_database(self.database) as connection:
            connection.execute("UPDATE skills SET effect_text = 'Updated effect' WHERE id = 1")
        self.assertNotEqual(self.run_export("--check").returncode, 0)
        self.assertEqual(self.output.read_bytes(), first_export)
        self.assertEqual(self.run_export().returncode, 0)
        self.assertEqual(json.loads(self.output.read_text(encoding="utf-8"))["skills"][0]["effect_text"], "Updated effect")

    def test_invalid_data_does_not_overwrite_a_working_export(self):
        self.assertEqual(self.run_export().returncode, 0)
        previous_export = self.output.read_bytes()
        with open_database(self.database) as connection:
            connection.execute("UPDATE skills SET usable_columns = '5' WHERE id = 1")
        self.assertNotEqual(self.run_export().returncode, 0)
        self.assertEqual(self.output.read_bytes(), previous_export)

    def test_fractional_ap_and_unlock_levels_are_rejected(self):
        with open_database(self.database) as connection:
            connection.execute("UPDATE skills SET ap_cost = 1.5 WHERE id = 1")
        with self.assertRaises(ValueError):
            skill_export.read_catalog(self.database)
        with open_database(self.database) as connection:
            connection.execute("UPDATE skills SET ap_cost = 1 WHERE id = 1")
            connection.execute("UPDATE job_skill_unlocks SET unlock_level = 1.5 WHERE skill_id = 1")
        with self.assertRaises(ValueError):
            skill_export.read_catalog(self.database)

    def test_export_cannot_overwrite_the_source_database(self):
        before = self.database.read_bytes()
        result = subprocess.run(
            [sys.executable, str(EXPORTER), "--database", str(self.database), "--output", str(self.database)],
            capture_output=True, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.database.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
