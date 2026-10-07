---
name: coredata
description: Core Data 코드를 작성, 수정, 리뷰할 때 사용한다. NSPersistentContainer, NSManagedObjectContext, NSFetchedResultsController, @FetchRequest, @SectionedFetchRequest, 배치 요청, Undo, 동기화, 마이그레이션을 다루는 작업이 대상이다. 로컬 데이터를 SOT로 두고 컨텍스트 변경을 감지해 UI에 반영하는 단일 플로우와 책임 분리 기준을 제공한다.
---

# Core Data 지침

## 1. 핵심 원칙: 로컬 스토어를 SOT로 둔다

로컬 데이터를 쓰는 화면에서는 Core Data 스토어를 SOT(Source of Truth, 단일 소스)로 둔다.
화면은 데이터를 따로 들고 있지 않고, 컨텍스트가 알려 주는 변경을 받아 다시 그리기만 한다.

```
쓰기(어느 컨텍스트든) → save 또는 병합 → viewContext 변경 → 변경 감지(FRC, @FetchRequest, KVO) → UI 갱신
```

- 상태를 여러 곳에 두지 않는다. 뷰컨트롤러 배열, ViewModel 배열, `@State` 사본에 엔티티 값을 복사해 두고 직접 고치지 않는다.
- 쓰기 경로는 화면을 직접 갱신하지 않는다. 저장만 하고, 갱신은 변경 감지 경로에 맡긴다.
- 화면 사이에는 객체 대신 `NSManagedObjectID`를 넘긴다. 받는 쪽은 자기 컨텍스트에서 객체를 다시 얻는다.
- 컨텍스트를 거치지 않는 변경(배치 요청, 외부 동기화)은 결과 objectID를 viewContext에 병합하거나 다시 fetch해서 같은 플로우로 합류시킨다.
- 편집 중인 임시 상태도 별도 변수가 아니라 편집용 컨텍스트 안의 객체에 둔다. 취소는 그 컨텍스트를 버리거나 rollback하는 것으로 끝난다.
- 화면에 그릴 모양과 엔티티 구조의 차이가 크면 렌더링 전용 Swift 타입(매핑 모델)을 만들어 엔티티에서 변환해 쓸 수 있다. 이때도 유효한 값의 기준은 로컬 스토어다.
  - 값이 존재하는 곳은 엔티티와 매핑 모델, 최대 두 곳이다. 매핑 모델을 다시 복사한 배열이나 `@State` 사본처럼 세 번째 위치를 만들지 않는다.
  - 두 곳 사이의 동기화는 한 방향으로만 흐른다. 매핑 모델은 엔티티에서만 만들고, 변경 감지 경로(FRC 콜백, `objectWillChange`, NotifcationCenter 콜백 등)에서만 다시 만든다.
  - 매핑 모델은 명새에 따라 쓰기 대상이 될 수 있으며, 변경된 매핑 모델이 엔티티로 재맵핑되어 저장되는 구조를 가질 수 있다.
  - 차이가 크지 않으면 매핑 모델을 만들지 않고 엔티티 속성을 직접 쓴다. 판단 기준은 references/stack.md의 "엔티티와 렌더링 모델 경계"에 있다.

예외: 검색어, 정렬 옵션, 시트 표시 여부처럼 스토어에 저장하지 않는 순수 UI 상태는 화면이 들고 있어도 된다.

## 2. 책임 지도

어느 아키텍처를 쓰든 아래 책임은 존재한다.
레퍼런스의 코드는 설명을 위해 UIKit에서는 뷰컨트롤러 하나가, SwiftUI에서는 뷰 하나가 대부분을 맡는다.
실제 코드에서는 아키텍처(MVC, MVVM, TCA 등)에 맞게 이 경계를 기준으로 나눈다.

| 책임 | 하는 일 | UIKit에서 맡는 곳 | SwiftUI에서 맡는 곳 |
| --- | --- | --- | --- |
| 스택 제공 | 모델 로드, 컨테이너 생성, 컨텍스트 설정 | 앱 진입점에서 컨테이너를 한 번 만들고, 화면과 쓰기 타입에 생성자로 주입한다 | 앱 진입점에서 만든 컨테이너의 viewContext를 Environment(`\.managedObjectContext`)로 주입받거나, ViewModel이 생성될 때 컨테이너를 주입받는다 |
| 쿼리 정의 | 엔티티, predicate, 정렬, 섹션 키 결정 | FRC를 만드는 함수 | `@FetchRequest`, `@SectionedFetchRequest` 선언 |
| 변경 감지 | 컨텍스트 변경을 받아 결과 목록 갱신 | FRC delegate | `@FetchRequest` 내부 FRC, 행 뷰의 `@ObservedObject` |
| UI 업데이트 매핑 | 변경 결과를 스냅샷, 애니메이션, 셀 갱신으로 변환 | `controller(_:didChangeContentWith:)`에서 스냅샷을 다듬어 apply | SwiftUI diff (자동) |
| 항목 표시 | objectID에서 객체를 얻어 셀이나 행에 값을 채움 | cell provider가 엔티티 속성을 직접 쓰거나, 매핑 모델로 바꿔 셀에 넘긴다 | 행 뷰가 `@ObservedObject`로 받은 엔티티 속성을 직접 쓰거나, 매핑 모델을 받는다 |
| 쓰기 | 삽입, 수정, 삭제, 배치, 동기화 | 편집 화면은 편집용 백그라운드 컨텍스트로 쓰고, 배치와 동기화는 화면을 모르는 별도 타입이 백그라운드 컨텍스트로 쓴다 | 목록 뷰는 viewContext로, 편집 시트는 자식 컨텍스트로, 무거운 작업은 백그라운드 컨텍스트로 쓴다 |
| 화면 | 레이아웃, 라우팅, 사용자 입력 전달 | 뷰컨트롤러 | 뷰 |

레퍼런스 코드는 모두 아래 엔티티 하나를 기준으로 쓴다. 타입 이름은 `Record` 뒤에 역할을 붙인다. (`RecordListViewController`, `RecordEditSheet`, `RecordSyncer` 등)

| 속성 | 타입 | 설정 |
| --- | --- | --- |
| `recordId` | String | 유니크 제약 |
| `title` | String, 옵셔널 | 인덱스 |
| `category` | String, 옵셔널 | `RecordCategory` enum의 원시값 |
| `amount` | Integer 32 | 기본값 0 |
| `isActive` | Boolean | 기본값 NO |
| `createdAt`, `updatedAt` | Date, 옵셔널 | `awakeFromInsert`에서 채움 |
| `cachedSummary` | String, 옵셔널 | Transient |

## 3. 상세 명세

작업 내용에 맞는 파일만 읽는다.
각 파일은 규칙과 그 규칙을 따르는 코드를 함께 담고 있다.

| 파일 | 읽을 때 |
| --- | --- |
| [references/uikit.md](references/uikit.md) | UIKit 목록 화면, FRC, diffable data source를 다룰 때 |
| [references/swiftui.md](references/swiftui.md) | SwiftUI 화면에서 Core Data를 쓸 때 |
| [references/stack.md](references/stack.md) | 모델 정의와 Codegen, 컨테이너와 컨텍스트 구성, 엔티티와 렌더링 모델 경계, 동시성, 에러 처리, 삭제된 객체 접근을 다룰 때 |
| [references/writes.md](references/writes.md) | 편집 화면, Undo/Redo, 배치 요청, 외부 데이터 동기화, refresh를 다룰 때 |
| [references/migration.md](references/migration.md) | 모델 버전을 추가하거나 마이그레이션을 구성할 때 |

## 4. 자주 틀리는 규칙 요약

- 엔티티, 속성, 관계는 `.xcdatamodeld`에서만 정의한다. Codegen은 Class Definition이 기본이고, 생명주기 함수나 추가 코드가 필요하면 Category/Extension을 쓴다. Manual/None은 쓰지 않는다. (stack.md)
- 같은 momd를 `NSManagedObjectModel(contentsOf:)`로 두 번 이상 로드하지 않는다. (stack.md)
- 백그라운드 컨텍스트는 `perform`이나 `performAndWait` 안에서만 쓴다. (stack.md)
- viewContext는 MainActor 격리 코드(SwiftUI `View`, `UIViewController`, `@MainActor` ViewModel)에서 `perform` 없이 직접 쓴다. `Record(context: viewContext)`로 객체를 만들고 바로 저장해도 된다. 이 허용은 viewContext에만 해당한다. (stack.md)
- 배치 요청 결과는 자동으로 병합되지 않는다. (writes.md)
- FRC 스냅샷의 아이템은 objectID라서 속성 변경은 diff에 잡히지 않는다. 스냅샷의 `reloadedItemIdentifiers`를 같은 스냅샷의 `reconfigureItems(_:)`에 넘긴 뒤 apply한다. (uikit.md)
- 매핑 모델을 쓰더라도 값이 있는 곳은 엔티티와 매핑 모델 두 곳까지다. 매핑 모델은 고쳐서 저장하지 않는다. (stack.md)
- SwiftUI에서 컨테이너를 전역 정적 프로퍼티로 꺼내 쓰지 않는다. Environment나 ViewModel 생성자로 주입받는다. (swiftui.md)
- SwiftUI 행 뷰는 `@ObservedObject`로 객체를 관찰하고, 속성을 읽기 전에 삭제 여부를 확인한다. (swiftui.md)
- `UIHostingController` 안에서 `NavigationStack`을 또 만들지 않는다. (swiftui.md)
