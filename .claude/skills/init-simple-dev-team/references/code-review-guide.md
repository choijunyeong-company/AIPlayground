# Code Review Guide

## 리뷰 목적

코드 리뷰는 코드베이스의 일관성을 유지하고, 아키텍처 위반을 방지하며, 잠재적 버그를 사전에 발견하기 위해 수행한다.

## 리뷰 우선순위

아래 순서대로 중요도를 판단한다.

1. **치명적 (Must Fix)** - 반드시 수정, 리더 세션을 통해 사용자 동의 필요
2. **권장 (Should Fix)** - 반영자가 수정
3. **제안 (Nice to Have)** - 반영자가 수정

## 치명적 항목 (Must Fix)

다음 항목에 해당하면 리더 세션을 통해 사용자 동의를 받아야 한다.

### 아키텍처 위반
- CoreFlow 레이어 구조 위반 (Core에서 UI 직접 접근, Screen에서 비즈니스 로직 수행 등)
- 모듈 의존성 방향 위반 (`Resource → CommonUI`, `CommonUI → Feature` 등 역방향 의존)
- Screen에서 Core의 State를 직접 변경하는 경우
- Flow를 거치지 않는 화면 전환

### 데이터 안전성
- Actor를 사용하지 않는 공유 가변 상태
- 메인 스레드 외에서의 UI 업데이트
- 강한 참조 순환 가능성 (클로저에서 `[weak self]` 누락)
- `async` 컨텍스트에서의 데이터 경합 가능성

### 의존성 규칙
- `@Autowired` 없이 서비스를 직접 생성하는 경우
- Provider에 등록되지 않은 서비스 사용
- 모듈 경계를 넘는 구체 타입 직접 참조 (프로토콜 미사용)

## 권장 항목 (Should Fix)

### 네이밍
- 파일명이 PascalCase를 따르지 않는 경우
- 프로퍼티/함수가 camelCase를 따르지 않는 경우
- CommonUI 컴포넌트에 `IV` 접두사가 누락된 경우
- 역할 접미사 누락 (`*Core`, `*Screen`, `*Flow`, `*Service`, `*Entity`, `*DTO`)

### CoreFlow 패턴 준수
- `reduce()`에서 부수 효과를 직접 실행하는 경우 (Effect로 반환해야 함)
- `bind()`에서 `forward(actions:)` 또는 `observeDistinctState()` 미사용
- 상태 구독 시 `observeDistinctState` 대신 직접 구독하는 경우
- `compactScope`를 사용해야 할 옵셔널 상태에 일반 `scope` 사용

### UI 구성
- SnapKit을 사용하지 않는 Auto Layout 코드
- `setupView()`, `setupConstraints()`가 extension으로 분리되지 않은 경우
- 매직 넘버가 `private enum Layout`에 정의되지 않은 경우
- UI 설정 메서드가 `configure()` 패턴을 따르지 않는 경우
- `@discardableResult`가 누락된 configure 체이닝 메서드

### Import 순서
- 시스템 프레임워크 → 아키텍처 프레임워크 → 앱 프레임워크 → 서드파티 → 리소스 순서 미준수

### 서비스 레이어
- 서비스가 프로토콜 없이 구체 클래스로만 정의된 경우
- 공유 데이터 캐싱에 Actor를 사용하지 않는 경우
- DTO → Entity 변환이 서비스 레이어에서 이루어지지 않는 경우

## 제안 항목 (Nice to Have)

### 코드 구조
- `// MARK: -` 주석으로 코드 영역이 구분되지 않은 경우
- guard 문 다음에 빈 줄이 없는 경우
- 단일 표현식 클로저에서 `$0` 축약형 미사용
- 3회 이상 사용되는 파라미터에 명시적 이름 미부여

### 타입 활용
- 원시값 대신 열거형을 사용할 수 있는 경우
- 프로토콜 지향 설계로 개선할 수 있는 경우

### 접근 제어
- 외부 노출이 불필요한 프로퍼티에 `private` 누락
- 이벤트 Publisher가 `AnyPublisher`로 은닉되지 않은 경우 (`PassthroughSubject` 직접 노출)

## 리뷰 코멘트 작성 형식

```
[우선순위] 파일명:라인번호
설명: 문제 상황에 대한 설명
제안: 수정 방향 또는 코드 예시
```

### 예시

```
[Must Fix] MiddleEffectMainScreen.swift:45
설명: Screen에서 서비스를 직접 호출하고 있습니다. 비즈니스 로직은 Core에서 처리해야 합니다.
제안: Action을 정의하고 Core의 reduce()에서 서비스 호출을 Effect로 처리하세요.
```

```
[Should Fix] MyTabView.swift:12
설명: 매직 넘버 `20`이 직접 사용되고 있습니다.
제안: `private enum Layout { static let padding: CGFloat = 20 }` 으로 분리하세요.
```

```
[Nice to Have] MyService.swift:30
설명: guard 문 다음에 빈 줄이 없습니다.
제안: guard 문과 후속 코드 사이에 빈 줄을 추가하세요.
```

## 리뷰 범위

### 리뷰 대상
- 새로 추가된 파일 전체
- 수정된 파일의 변경된 부분 및 변경과 직접 관련된 주변 코드

### 리뷰 제외
- 자동 생성 코드 (Tuist generated, Xcode boilerplate)
- 리소스 파일 (이미지, 폰트 등)
- 서드파티 라이브러리 코드
