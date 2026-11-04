"""Export the authoring SQLite database into Godot's read-only skill catalog."""

import argparse
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATABASE = PROJECT_ROOT / "data/sql/skill_database.sqlite"
DEFAULT_OUTPUT = PROJECT_ROOT / "data/skills/skill_database.json"


def parse_columns(value: str, skill_id: int) -> list[int]:
    if not value.strip():
        return [1, 2, 3, 4]
    try:
        columns = sorted({int(part.strip()) for part in value.split(",")})
    except ValueError as error:
        raise ValueError(f"Skill {skill_id}: usable_columns must contain column numbers") from error
    if not columns or not set(columns).issubset({1, 2, 3, 4}):
        raise ValueError(f"Skill {skill_id}: usable_columns must be within 1..4")
    return columns


def read_catalog(database: Path) -> dict:
    with closing(sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True, timeout=3)) as connection:
        connection.row_factory = sqlite3.Row
        connection.execute("BEGIN")
        if connection.execute("PRAGMA quick_check").fetchone()[0] != "ok":
            raise ValueError("The skill database failed its integrity check")
        if connection.execute("PRAGMA foreign_key_check").fetchall():
            raise ValueError("The skill database contains broken foreign keys")
        skills = [dict(row) for row in connection.execute("SELECT * FROM skills ORDER BY id")]
        jobs = [dict(row) for row in connection.execute("SELECT * FROM jobs ORDER BY id")]
        types = [dict(row) for row in connection.execute("SELECT * FROM skill_types ORDER BY id")]
        unlocks = [dict(row) for row in connection.execute(
            "SELECT job_id, skill_id, unlock_level FROM job_skill_unlocks "
            "ORDER BY job_id, unlock_level, skill_id"
        )]

    for skill in skills:
        skill_id = skill["id"]
        if skill_id < 1 or skill["skill_type_id"] not in (1, 2):
            raise ValueError(f"Skill {skill_id}: unsupported ID or skill type")
        if skill["damage_type"] not in (0, 1, 2):
            raise ValueError(f"Skill {skill_id}: unsupported damage type")
        if skill["ap_cost"] is not None and (
            not isinstance(skill["ap_cost"], int) or skill["ap_cost"] < 0
        ):
            raise ValueError(f"Skill {skill_id}: AP cost must be a non-negative integer or NULL")
        skill["usable_columns"] = parse_columns(skill["usable_columns"], skill_id)
    if any(not isinstance(unlock["unlock_level"], int) or not 1 <= unlock["unlock_level"] <= 10 for unlock in unlocks):
        raise ValueError("Job skill unlock levels must be within 1..10")
    return {
        "format_version": 1,
        "skill_types": types,
        "skills": skills,
        "jobs": jobs,
        "job_skill_unlocks": unlocks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, default=DEFAULT_DATABASE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="Check that the export matches the saved DB")
    arguments = parser.parse_args()
    try:
        if arguments.database.resolve() == arguments.output.resolve():
            raise ValueError("The output must not overwrite the SQLite database")
        catalog = read_catalog(arguments.database)
        serialized = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
        if arguments.check:
            if not arguments.output.is_file() or arguments.output.read_text(encoding="utf-8") != serialized:
                print("Skill catalog is out of date. Run tools/export_skill_database.py.", file=sys.stderr)
                return 1
        elif not arguments.output.is_file() or arguments.output.read_text(encoding="utf-8") != serialized:
            arguments.output.parent.mkdir(parents=True, exist_ok=True)
            arguments.output.write_text(serialized, encoding="utf-8", newline="\n")
        print(f"Skill catalog: {len(catalog['skills'])} skills, {len(catalog['job_skill_unlocks'])} unlocks")
        return 0
    except (OSError, sqlite3.Error, ValueError, KeyError, TypeError) as error:
        print(f"Skill export failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
