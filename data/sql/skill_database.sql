-- City of Star skill database seed
-- Target engine: SQLite 3
--
-- Usage:
--   sqlite3 skill_database.sqlite < data/sql/skill_database.sql

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

DROP TABLE IF EXISTS job_skill_unlocks;
DROP TABLE IF EXISTS skills;
DROP TABLE IF EXISTS skill_types;
DROP TABLE IF EXISTS jobs;
DROP TABLE IF EXISTS skill_conditions;
DROP TABLE IF EXISTS combat_rules;
DROP TABLE IF EXISTS source_documents;
DROP TABLE IF EXISTS schema_metadata;

CREATE TABLE jobs (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL UNIQUE
);

CREATE TABLE skill_types (
    id INTEGER PRIMARY KEY,
    display_name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT ''
);

CREATE TABLE skills (
    id INTEGER PRIMARY KEY,
    display_name TEXT NOT NULL UNIQUE,
    skill_type_id INTEGER NOT NULL,
    ap_cost INTEGER,
    effect_text TEXT NOT NULL,
    usable_columns TEXT NOT NULL DEFAULT '',
    unusable_columns TEXT NOT NULL DEFAULT '',
    required_equipment TEXT NOT NULL DEFAULT '',
    target_text TEXT NOT NULL DEFAULT '',
    FOREIGN KEY (skill_type_id) REFERENCES skill_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CHECK (ap_cost IS NULL OR ap_cost >= 0)
);

CREATE TABLE job_skill_unlocks (
    job_id TEXT NOT NULL,
    skill_id INTEGER NOT NULL,
    unlock_level INTEGER NOT NULL,
    PRIMARY KEY (job_id, skill_id),
    FOREIGN KEY (job_id) REFERENCES jobs(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES skills(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CHECK (unlock_level >= 1)
);

CREATE INDEX idx_skills_type ON skills(skill_type_id);
CREATE INDEX idx_job_skill_unlocks_skill ON job_skill_unlocks(skill_id);

INSERT INTO jobs (id, display_name) VALUES
    ('Fighter', '투사'),
    ('Archer', '사수'),
    ('Mage', '마법사'),
    ('Priest', '사제'),
    ('Spy', '첩자'),
    ('Trickster', '재주꾼');

INSERT INTO skill_types (id, display_name, description) VALUES
    (1, '액티브', '턴 중 AP나 조건을 소비해 직접 사용하는 스킬'),
    (2, '패시브', '조건을 만족하면 지속적으로 적용되는 스킬');

INSERT INTO skills (
    id,
    display_name,
    skill_type_id,
    ap_cost,
    effect_text,
    usable_columns,
    unusable_columns,
    required_equipment,
    target_text
) VALUES
    (
        1,
        '돌진',
        1,
        NULL,
        '앞으로 2열 전진하면서 같은 행의 1열을 공격한다.',
        '2,3,4',
        '1',
        '근접무기',
        '같은 행의 1열'
    ),
    (
        2,
        '내구력',
        2,
        NULL,
        '받는 피해가 10% 감소한다.',
        '1,2,3,4',
        '',
        '',
        '자신'
    );

INSERT INTO job_skill_unlocks (job_id, skill_id, unlock_level) VALUES
    ('Fighter', 1, 1),
    ('Fighter', 2, 2);

COMMIT;
