# 초기 구조

이 프로젝트는 실제 콘텐츠 데이터를 만들기 전에 게임의 뼈대를 먼저 고정하기 위한 Godot 4 구조입니다.

## 런타임 싱글톤

- `ContentCatalog`: `data/` 아래의 카드와 의뢰 Resource를 읽어 인덱싱합니다.
- `GameState`: 날짜, 사무소 상태, 세금, 게임 오버 조건을 관리합니다.

## 도메인 모델

- `StatBlock`: 힘, 민첩, 지능, 매력 묶음입니다.
- `CardDefinition`: 인물, 장비, 소비 카드를 같은 형식으로 정의합니다.
- `RequestDefinition`: 스토리, 일반, 이벤트 의뢰를 같은 형식으로 정의합니다.
- `ActiveRequest`: 수주된 의뢰의 남은 일수와 완료 상태를 관리합니다.
- `OfficeState`: 자금, 명성, 보유 카드, 대기 의뢰, 진행 의뢰를 보관합니다.
- `TaxManager`: 주차와 세금 납부 상태를 계산합니다.

## 콘텐츠 추가 위치

현재 `data/cards`와 `data/requests`는 비어 있습니다. 나중에 Godot Resource 파일인 `.tres` 또는 `.res`를 추가하면 `ContentCatalog`가 재귀적으로 읽습니다.

초기에는 실제 인물, 장비, 소비 아이템, 이벤트 의뢰 데이터를 만들지 않았습니다. 대신 해당 데이터를 받을 수 있는 타입과 로딩 구조만 준비했습니다.
