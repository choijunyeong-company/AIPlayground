# 작업개요

MeeusCalculator 기반 동적 계산 방식을 폐지하고, 기상청 공식 데이터를 JSON 정적 파일로 관리하여 절기 정보를 제공하는 로컬 저장소 플로우를 구현한다.

# Task1: Data 타겟 Resource 디렉터리 Tuist 설정

Tuist ProjectDescriptionHelpers에서 Data 모듈의 Target 설정에 `resourceSync` 또는 `resources` 규칙을 추가하여, `Projects/Data/Resources/` 디렉터리의 파일이 번들에 포함되도록 설정한다.

- 대상 파일: `Tuist/ProjectDescriptionHelpers/Module/Target.swift` (또는 해당 프로젝트 정의 파일)
- Data 모듈에만 리소스가 포함되도록 변경
- `Projects/Data/Resources/` 디렉토리를 생성

# Task2: 절기 정보 JSON 파일 생성
- dependencies: [Task1]

`Projects/Data/Resources/` 디렉토리에 연도별 JSON 파일을 생성한다.

**파일명 규칙**: `solar_term_{연도}.json` (예: `solar_term_2026.json`)

**JSON 구조**:
```json
{
  "year": 2026,
  "terms": [
    { "id": "sohan", "month": 1, "day": 5 },
    { "id": "daehan", "month": 1, "day": 20 },
    { "id": "ipchun", "month": 2, "day": 4 },
    ...
  ]
}
```

- `id`는 `SolarTerm` enum case명과 일치 (소문자 영문)
- 연도 내 시간순 정렬 (소한 → 대한 → 입춘 → ... → 동지)
- 생성 연도: 2024, 2025, 2026 (3개 파일)
- 각 연도의 절기 데이터는 사용자가 제공한 기상청 공식 데이터를 사용

**데이터 출처** (사용자 제공 기상청 데이터):

**2024년**:
| 월 | 일 | 절기 | id |
|----|-----|------|-----|
| 1 | 6 | 소한 | sohan |
| 1 | 20 | 대한 | daehan |
| 2 | 4 | 입춘 | ipchun |
| 2 | 19 | 우수 | usu |
| 3 | 5 | 경칩 | gyeongchip |
| 3 | 20 | 춘분 | chunbun |
| 4 | 4 | 청명 | cheongmyeong |
| 4 | 19 | 곡우 | gogu |
| 5 | 5 | 입하 | ibha |
| 5 | 20 | 소만 | soman |
| 6 | 5 | 망종 | mangjong |
| 6 | 21 | 하지 | haji |
| 7 | 6 | 소서 | soseo |
| 7 | 22 | 대서 | daeseo |
| 8 | 7 | 입추 | ibchu |
| 8 | 22 | 처서 | cheoseo |
| 9 | 7 | 백로 | baengno |
| 9 | 22 | 추분 | chubun |
| 10 | 8 | 한로 | hanro |
| 10 | 23 | 상강 | sanggang |
| 11 | 7 | 입동 | ibdong |
| 11 | 22 | 소설 | soseol |
| 12 | 7 | 대설 | daeseol |
| 12 | 21 | 동지 | dongji |

**2025년**:
| 월 | 일 | 절기 | id |
|----|-----|------|-----|
| 1 | 5 | 소한 | sohan |
| 1 | 20 | 대한 | daehan |
| 2 | 3 | 입춘 | ipchun |
| 2 | 18 | 우수 | usu |
| 3 | 5 | 경칩 | gyeongchip |
| 3 | 20 | 춘분 | chunbun |
| 4 | 4 | 청명 | cheongmyeong |
| 4 | 20 | 곡우 | gogu |
| 5 | 5 | 입하 | ibha |
| 5 | 21 | 소만 | soman |
| 6 | 5 | 망종 | mangjong |
| 6 | 21 | 하지 | haji |
| 7 | 7 | 소서 | soseo |
| 7 | 22 | 대서 | daeseo |
| 8 | 7 | 입추 | ibchu |
| 8 | 23 | 처서 | cheoseo |
| 9 | 7 | 백로 | baengno |
| 9 | 23 | 추분 | chubun |
| 10 | 8 | 한로 | hanro |
| 10 | 23 | 상강 | sanggang |
| 11 | 7 | 입동 | ibdong |
| 11 | 22 | 소설 | soseol |
| 12 | 7 | 대설 | daeseol |
| 12 | 22 | 동지 | dongji |

**2026년**:
| 월 | 일 | 절기 | id |
|----|-----|------|-----|
| 1 | 5 | 소한 | sohan |
| 1 | 20 | 대한 | daehan |
| 2 | 4 | 입춘 | ipchun |
| 2 | 19 | 우수 | usu |
| 3 | 5 | 경칩 | gyeongchip |
| 3 | 20 | 춘분 | chunbun |
| 4 | 5 | 청명 | cheongmyeong |
| 4 | 20 | 곡우 | gogu |
| 5 | 5 | 입하 | ibha |
| 5 | 21 | 소만 | soman |
| 6 | 6 | 망종 | mangjong |
| 6 | 21 | 하지 | haji |
| 7 | 7 | 소서 | soseo |
| 7 | 23 | 대서 | daeseo |
| 8 | 7 | 입추 | ibchu |
| 8 | 23 | 처서 | cheoseo |
| 9 | 7 | 백로 | baengno |
| 9 | 23 | 추분 | chubun |
| 10 | 8 | 한로 | hanro |
| 10 | 23 | 상강 | sanggang |
| 11 | 7 | 입동 | ibdong |
| 11 | 22 | 소설 | soseol |
| 12 | 7 | 대설 | daeseol |
| 12 | 22 | 동지 | dongji |

# Task3: 절기 엔티티 구현

Domain 모듈의 절기 관련 코드를 정리하고, 새로운 절기 엔티티를 구현한다.

**3-1. 기존 코드 정리**:
- `SolarTerm` enum: case 항목만 유지, 모든 함수/연산프로퍼티/이니셜라이저/extension 제거
- `SolarLongitudeCalculator` 프로토콜 제거
- `MeeusCalculator.swift` 제거
- `SolarTermTests.swift` (테스트 파일) 제거

**3-2. 새 절기 엔티티 구현** (`Projects/Domain/Sources/Entity/Common/`):
```swift
struct SolarTermInfo {
    let term: SolarTerm     // 절기 정보
    let startDate: Date     // 절기 시작일
    let endDate: Date       // 절기 종료일 (다음 절기 시작일)
    var dateRange: Range<Date> { startDate..<endDate }  // 연산 프로퍼티
}
```

- `endDate`는 다음 절기의 `startDate`와 동일
- 마지막 절기(동지)의 `endDate`는 해당 연도 12월 31일 23:59:59로 설정

# Task4: 절기 Repository 구현
- dependencies: [Task2, Task3]

`@DependencyClient` 패턴으로 절기 Repository를 구현한다.

**4-1. Domain - 인터페이스 정의** (`Projects/Domain/Sources/Repository/`):
```swift
@DependencyClient
struct SolarTermRepository {
    var fetchSolarTerms: @Sendable (_ year: Int) async throws -> [SolarTermInfo]
}
```

**4-2. Data - DTO 정의** (`Projects/Data/Sources/DTO/`):
- JSON 매핑용 DTO 구조체
- `toDomain()` extension에서 DTO → Entity 변환 (endDate 계산 로직 포함)

**4-3. Data - Repository 구현** (`Projects/Data/Sources/Repository/`):
- `liveValue` 구현체 제공
- `Bundle.main`에서 `solar_term_{year}.json` 파일 로드
- JSON 디코딩 → DTO → Entity 매핑
- 파일이 없는 연도 요청 시 적절한 에러 처리
- 캐싱 불필요 (JSON 파싱 오버헤드가 낮음)

**에러 처리**:
- JSON 파일이 없는 경우: 빈 배열 반환 또는 DomainError 발생
- 디코딩 실패 시: DomainError로 매핑
