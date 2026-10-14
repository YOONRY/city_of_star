-- 스킬 추가 명령어 양식
-- 아래 예시 값을 새 스킬 정보로 바꾼 뒤 실행하세요.
-- skill_type_id: 1 = 액티브, 2 = 패시브
-- ap_cost: 소모 AP가 없으면 NULL

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

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
) VALUES (
    3,                          -- 스킬 ID (중복되지 않는 숫자)
    '새 스킬 이름',             -- 표시 이름
    1,                          -- 1: 액티브 / 2: 패시브
    2,                          -- AP 소모량 / 없으면 NULL
    '스킬 효과 설명',           -- 효과
    '1,2,3,4',                  -- 사용 가능 열 / 제한 없으면 빈 문자열
    '',                         -- 사용 불가능 열 / 없으면 빈 문자열
    '근접무기',                 -- 필요 장비 / 없으면 빈 문자열
    '적 1명'                    -- 대상
);

-- 직업 스킬이 아니라면 아래 INSERT 문은 삭제하세요.
-- job_id: Fighter, Archer, Mage, Priest, Spy, Trickster
INSERT INTO job_skill_unlocks (
    job_id,
    skill_id,
    unlock_level
) VALUES (
    'Fighter',                  -- 습득 직업 ID
    3,                          -- 위에서 입력한 스킬 ID
    1                           -- 습득 직업 레벨
);

COMMIT;
