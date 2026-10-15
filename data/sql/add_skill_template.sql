-- 스킬 추가 명령어 양식
-- 아래 예시 값을 새 스킬 정보로 바꾼 뒤 실행하세요.
-- skill_type_id: 1 = 액티브, 2 = 패시브
-- ap_cost: 소모 AP가 없으면 NULL
-- usable_columns: 사용 가능한 열만 입력 / 빈 문자열이나 공백이면 모든 열에서 사용 가능
-- main_stat: 힘, 민첩, 지능, 매력, 체력 / 주 스탯이 없거나 미정이면 빈 문자열
-- damage_type: 0 = 피해 없음/미정, 1 = 물리 피해, 2 = 마법 피해

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

INSERT INTO skills (
    id,
    display_name,
    skill_type_id,
    ap_cost,
    effect_text,
    usable_columns,
    required_equipment,
    target_text,
    main_stat,
    damage_type
) VALUES (
    NULL,                       -- 스킬 ID 자동 발급 / 직접 지정하려면 중복되지 않는 숫자
    '새 스킬 이름',             -- 표시 이름
    1,                          -- 1: 액티브 / 2: 패시브
    2,                          -- AP 소모량 / 없으면 NULL
    '스킬 효과 설명',           -- 효과
    '1,2,3,4',                  -- 사용 가능 열 / 제한 없으면 빈 문자열
    '근접무기',                 -- 필요 장비 / 없으면 빈 문자열
    '적 1명',                   -- 대상
    '힘',                       -- 주 스탯 / 없거나 미정이면 빈 문자열
    1                           -- 피해 구분 / 0: 없음·미정, 1: 물리, 2: 마법
);

-- 직업 스킬이 아니라면 아래 INSERT 문은 삭제하세요.
-- job_id: Fighter, Archer, Mage, Priest, Spy, Trickster
INSERT INTO job_skill_unlocks (
    job_id,
    skill_id,
    unlock_level
) VALUES (
    'Fighter',                  -- 습득 직업 ID
    last_insert_rowid(),         -- 바로 위에서 추가한 스킬 ID
    1                           -- 습득 직업 레벨
);

COMMIT;
