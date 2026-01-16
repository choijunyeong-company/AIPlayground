# CoreFlow 아키텍처 설명

CoreFlow는 Core, Flow, Screen 세 가지 컴포넌트로 구성된 Feature 단위입니다.
애플리케이션의 각 기능은 CoreFlow 단위로 생성되며, 트리 형태로 CoreFlow 간 흐름을 연결할 수 있습니다.
화면이 필요 없는 Feature의 경우 Screen 컴포넌트는 생략할 수 있습니다.

# 구성요소 설명

## Flow

### 책임

- 계층 관리: CoreFlow 계층을 실질적으로 관리하며, 하위 CoreFlow의 Flow 객체를 참조합니다.
- 계층 이동: CoreFlow 내 정의된 Routing 프로토콜을 구현하며, Core로부터 수신한 라우팅 요청을 수행합니다. 여기서 Routing은 하위 CoreFlow를 생성하여 화면 또는 실행 흐름을 이동시키는 것을 의미합니다.
- Core, Screen 참조: Core와 Screen 객체는 Flow에 의해 참조되어 메모리에 유지됩니다. Flow가 메모리에서 해제된 이후에도 두 객체가 메모리에 남아있는 경우 LeakDetector에 의해 감지됩니다.

### 코드 예시

아래 경로의 파일을 확인해주세요.
[Flow.md](./docs/Flow.md)

## SLFlow

CoreFlow가 화면을 가지지 않고 오직 로직만을 가지는 경우에 사용합니다.

### 책임

Flow와 대부분 동일하지만, Screen에 대한 참조를 관리하지 않는다는 점에서 차이가 있습니다.

### 주의 사항

- 해당 객체의 경우 Core가 아닌 SLCore와 함께 사용됩니다.

## Core

### 책임

- 화면 상태 관리: 화면에 사용되는 상태를 관리합니다. Screen에는 UI 관련 코드만 존재합니다.
- 단방향 스트림 관리: 화면으로부터 액션을 수신하며, 해당 액션으로부터 파생된 상태 변화와 파생 액션을 단방향으로 관리합니다.
- 라우팅 요청: Routing 프로토콜을 채택하는 router 프로퍼티를 가집니다. 화면 간 이동 또는 실행 흐름 간 이동이 필요한 경우 해당 객체에 요청합니다.
- 리스너 요청: Listener 프로토콜을 채택하는 listener 프로퍼티를 가집니다. 상위 CoreFlow에 요청사항이 있는 경우(현재 CoreFlow 제거 등) 요청을 보냅니다.
- 프로시저 스텝 구현: 프로시저의 특정 단계마다 실행할 액션을 구현합니다. 자세한 내용은 Procedure 섹션을 확인해주세요.

### 코드 예시

아래 경로의 파일을 확인해주세요.
[Core.md](./docs/Core.md)

## SLCore

CoreFlow가 화면을 가지지 않고 오직 로직만을 가지는 경우에 사용합니다.

### 책임

Core 타입과 같은 책임을 가지지만, 액션을 가지지 않으며 단방향 아키텍처 역시 가지지 않습니다.

## Screen

### 책임

- 화면: UIViewController를 상속합니다.
- 액션 전달: UI가 수신한 액션을 Reactor(Core)에 송신합니다.
- 상태 수신: Reactor로부터 수신한 상태 변경을 UI에 반영합니다.

### 코드 예시

아래 경로의 파일을 확인해주세요.
[Screen.md](./docs/Screen.md)