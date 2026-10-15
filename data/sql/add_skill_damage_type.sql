-- 기존 스킬 DB에 피해 구분 열을 추가합니다.
-- damage_type 열이 없는 DB에 한 번만 실행하세요.
-- 0: 피해 없음/미정, 1: 물리 피해, 2: 마법 피해

PRAGMA foreign_keys = ON;

BEGIN IMMEDIATE;

ALTER TABLE skills
ADD COLUMN damage_type INTEGER NOT NULL DEFAULT 0
CHECK (damage_type IN (0, 1, 2));

UPDATE skills
SET damage_type = 1
WHERE (id, display_name, required_equipment) IN (
    (1, '돌진', '근접무기'),
    (5, '강타', '근접무기'),
    (9, '일격', '근접무기'),
    (11, '한 발에 두 놈', '사격무기'),
    (13, '속박사격', '사격무기')
);

COMMIT;
