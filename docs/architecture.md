# 초기 구조

이 프로젝트는 실제 콘텐츠 데이터를 만들기 전에 게임의 뼈대를 먼저 고정하기 위한 Godot 4 구조입니다.

## 런타임 싱글톤

- `ContentCatalog`: 카드·직업·종족·의뢰 Resource와 내보낸 스킬 JSON을 읽어 인덱싱합니다.
- `GameState`: 날짜, 사무소 상태, 세금, 게임 오버 조건을 관리합니다.

## 도메인 모델

- `StatBlock`: 성장 가능한 힘·민첩·지능·매력·체력과 장비·스킬 전용 방어력·마법 방어력을 담습니다.
- `CardDefinition`: 인물, 장비, 소비 카드를 같은 형식으로 정의합니다.
- `SkillDefinition`: 숫자 스킬 ID, 액티브/패시브, AP, 효과 설명, 사용 열, 요구 장비, 대상, 주 스탯, 피해 구분을 담습니다.
- `RequestDefinition`: 스토리, 일반, 이벤트 의뢰를 같은 형식으로 정의합니다.
- `ActiveRequest`: 수주된 의뢰의 남은 일수와 완료 상태를 관리합니다.
- `OfficeState`: 자금, 명성, 보유 카드, 대기 의뢰, 진행 의뢰를 보관합니다.
- `TaxManager`: 주차와 세금 납부 상태를 계산합니다.

## 콘텐츠 추가 위치

`data/cards`, `data/jobs`, `data/species`, `data/requests`의 `.tres` 또는 `.res`를 `ContentCatalog`가 재귀적으로 읽습니다.

## 시설 이벤트

상점과 인력 사무소는 의뢰 판정과 별도로 매일 이벤트 목록에 표시됩니다. `GameState`는 확정한 시설별 담당 인물을 보관하고
일일 의뢰·직업 교육과의 중복 배치를 검사합니다. 확정된 배치는 하루를 넘기기 전까지 취소할 수 있습니다. 날짜가 바뀌면 담당 인물은
해제되고, 확정된 시설만 그날 이용할 수 있게 됩니다. UI는 정산과 전직 처리가 끝난 뒤 이용 가능한 시설을 하나씩 자동으로 엽니다.

상점 가격은 카드 Resource의 `shop_price`입니다. 양수인 장비·소비 카드만 거래 대상으로 삼으며, 판매가는 구매가의 절반(내림)입니다.
구매 시 `OfficeState.owned_cards`에 추가하고, 판매 시 목록에서 제거합니다. 같은 카드를 중복 보유할 수 없으며 장착 중인 장비는 판매할 수 없습니다.

## 스킬 데이터 흐름

`data/sql/skill_database.sqlite` → `tools/export_skill_database.py` → `data/skills/skill_database.json` → `ContentCatalog` → 직업 해금 및 인물 스킬 탭

SQLite는 작성 원본이고, JSON은 재생성 가능한 게임용 데이터입니다. 게임 실행 시 Python이나 SQLite 확장이 필요하지 않습니다.
DB의 숫자 ID를 `SkillDefinition.id`로 사용합니다. 기존 `JobDefinition.skill_ids` 배열과 호환되도록 직업 내부에서는
숫자 ID의 문자열을 저장하며, 성장치·전직 조건은 기존 직업 Resource를 유지합니다. DB 직업은 스킬·습득 레벨을 덮어쓰고,
DB에 없는 상위직업은 기존 Resource 정의를 유지합니다. 직업 Resource는 복제한 뒤 DB 정보를 반영해 원본 캐시를 오염시키지 않습니다.

`GameState.get_character_skill_use_errors`는 습득, AP, 사용 열과 장비 조건만 검사합니다. 효과 설명문에서 숫자를 추측하거나
임의의 코드를 실행하지 않습니다. 전투 시스템에서 이 검사를 통과한 뒤 스킬별 효과 처리, AP 차감과 턴 진행을 연결해야 합니다.
