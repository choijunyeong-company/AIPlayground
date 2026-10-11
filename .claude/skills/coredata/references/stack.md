# 스택, 모델 경계, 동시성, 에러 처리

## 모델 정의와 Codegen

- 엔티티, 속성, 관계, 유니크 제약, 인덱스는 반드시 `.xcdatamodeld` 파일에서 정의한다. 코드에서 `NSEntityDescription`을 만들어 모델을 구성하지 않는다.
- 엔티티 클래스는 모델 편집기의 Codegen 설정으로 만든다.

| Codegen | 쓸 때 | 직접 작성하는 것 |
| --- | --- | --- |
| Class Definition | 기본값. 클래스에 추가할 코드가 없을 때 | 없음 |
| Category/Extension | 생명주기 함수(`awakeFromInsert`, `didTurnIntoFault` 등)나 별도 프로퍼티, 메서드가 필요할 때 | `@objc(Name) class Name: NSManagedObject` 선언과 그 안의 코드 |
| Manual/None | 특별한 이유가 없는 한 쓰지 않는다 | 클래스와 모든 `@NSManaged` 속성 |

- Category/Extension에서는 Xcode가 속성 접근자(`Name+CoreDataProperties`)를 빌드할 때 생성한다. 직접 쓰는 파일에는 클래스 선언, 생명주기 함수, 계산 프로퍼티, 변환 함수만 둔다.
- 생성된 파일은 DerivedData에 있으므로 수정하지 않는다. 속성을 바꿀 때는 모델 편집기에서 바꾼다.
- 생명주기 함수나 추가 코드가 필요해지면 Codegen을 Class Definition에서 Category/Extension으로 바꾼다. 같은 이름의 클래스를 직접 선언한 상태로 Class Definition을 유지하면 클래스가 중복 정의되어 빌드가 실패한다.
- Manual/None은 모델 편집기와 코드가 따로 움직여 속성 이름이나 타입이 어긋나기 쉽다. 쓰려면 이유를 코드 주석에 남긴다.

### 코드

```swift
// Codegen: Category/Extension
// recordId, title, category, amount, isActive, createdAt, updatedAt, cachedSummary 접근자는 Xcode가 생성한다.
@objc(Record)
class Record: NSManagedObject {
    // 엔티티가 처음 생성되어 컨텍스트에 삽입될 때 한 번만 호출된다.
    // NSBatchInsertRequest는 관리 객체를 거치지 않으므로 이 함수가 호출되지 않는다. 배치 삽입에서는 같은 값을 직접 넣는다.
    override func awakeFromInsert() {
        super.awakeFromInsert()
        recordId = UUID().uuidString
        createdAt = .now
        updatedAt = .now
    }
}
```

## 컨테이너와 컨텍스트 역할

| 대상 | 역할 | 설정 |
| --- | --- | --- |
| `NSManagedObjectModel` | 앱 전체에서 momd당 한 인스턴스 | 정적 프로퍼티로 한 번만 로드. 모델은 스토어 상태를 갖지 않으므로 컨테이너와 달리 전역에 두어도 된다 |
| `NSPersistentContainer` | 스토어 파일 하나에 하나 | 스토어 URL을 명시한 `NSPersistentStoreDescription` |
| `viewContext` | UI 읽기, 가벼운 단건 쓰기 | `automaticallyMergesChangesFromParent = true` |
| 백그라운드 컨텍스트 | 무거운 쓰기, 배치 요청, 동기화, UIKit 편집 화면 | `newBackgroundContext()`로 작업마다 생성 |
| 자식 컨텍스트 | 취소 가능한 편집 공간 | `parent = viewContext`, main queue |

- 같은 momd를 `NSManagedObjectModel(contentsOf:)`로 여러 번 로드하지 않는다. 같은 클래스를 여러 엔티티 설명이 차지해 `Multiple NSEntityDescriptions claim the NSManagedObject subclass` 경고가 나고, `Record.entity()`나 `Record(context:)`가 엉뚱한 모델의 엔티티를 고를 수 있다.
- 같은 모델을 쓰는 컨테이너가 여러 개면 모델 인스턴스 하나를 공유한다.
- 컨테이너는 앱 진입점(`App`, `AppDelegate`, `SceneDelegate`)에서 스토어마다 한 번 만들고, 쓰는 쪽에 주입한다.
  - UIKit: 뷰컨트롤러와 쓰기 타입의 생성자로 컨테이너를 넘긴다.
  - SwiftUI: viewContext를 Environment(`\.managedObjectContext`)로 넘기거나, ViewModel 생성자로 컨테이너를 넘긴다.
  - 화면이나 ViewModel이 필요할 때마다 컨테이너를 새로 만들지 않는다. 같은 스토어 파일에 코디네이터가 여러 개 붙어 변경 알림과 병합이 서로 전달되지 않는다.
  - 전역 정적 프로퍼티로 꺼내 쓰지 않는다. 테스트에서 메모리 스토어로 바꿔 끼울 수 없고, 어떤 화면이 어떤 스토어에 의존하는지 코드에서 드러나지 않는다.
- 모델 인스턴스가 여러 개일 수밖에 없는 경로에서는 배치 요청을 `entity()` 대신 엔티티 이름으로 만든다. (`NSBatchInsertRequest(entityName:)`)
- iOS의 viewContext는 `undoManager`가 기본값 `nil`이다. Undo가 필요하면 직접 넣는다.
- merge policy는 컨텍스트별로 의도에 맞게 정한다.
  - upsert를 실행하는 컨텍스트: `mergeByPropertyObjectTrump` (메모리 값 우선)
  - 백그라운드 병합 결과를 우선할 viewContext: `NSMergeByPropertyStoreTrumpMergePolicy`
- 새 객체의 식별자와 생성 시각은 `awakeFromInsert`에서 채운다. 삽입될 때 한 번만 호출된다.

### 코드

```swift
extension NSManagedObjectModel {
    // 같은 momd를 쓰는 컨테이너가 여러 개여도 모델은 한 번만 로드해 공유한다.
    static let app: NSManagedObjectModel = {
        guard
            let url = Bundle.main.url(forResource: "AppModel", withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: url)
        else { fatalError("AppModel 모델을 찾을 수 없습니다.") }
        return model
    }()
}

// 스토어 파일 하나에 컨테이너 하나를 만든다.
func makeContainer(storeName: String, model: NSManagedObjectModel) -> NSPersistentContainer {
    let container = NSPersistentContainer(name: storeName, managedObjectModel: model)
    let storeURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("\(storeName).sqlite")
    container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]

    // SQLite 스토어는 기본 설정에서 동기로 로드되므로 콜백이 반환 전에 호출된다.
    var loadError: Error?
    container.loadPersistentStores { _, error in
        loadError = error
    }
    if let loadError {
        // 스토어를 열 수 없으면 앱이 동작할 수 없다.
        fatalError(loadError.localizedDescription)
    }

    // 일반 컨텍스트 save()를 viewContext에 자동 병합한다.
    // 배치 요청은 save 알림이 없으므로 이 옵션으로 병합되지 않는다.
    container.viewContext.automaticallyMergesChangesFromParent = true
    return container
}

// 앱이 쓰는 컨테이너를 만들고, 용도에 맞게 viewContext를 설정한다.
func makeAppContainer() -> NSPersistentContainer {
    let container = makeContainer(storeName: "AppStore", model: .app)
    // recordId 유니크 제약이 충돌하면 스토어 값을 우선한다.
    container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    // iOS의 viewContext는 undoManager 기본값이 nil이다.
    container.viewContext.undoManager = UndoManager()
    return container
}
```

Environment로 viewContext만 주입받은 SwiftUI 뷰는 컨테이너가 없으므로 `newBackgroundContext()`를 부를 수 없다.
같은 코디네이터를 쓰는 private queue 컨텍스트를 만들어 같은 역할을 하게 한다.

```swift
extension NSManagedObjectContext {
    // container.newBackgroundContext()와 같은 역할을 한다.
    // 같은 코디네이터에서 저장하므로 automaticallyMergesChangesFromParent가 켜진 viewContext에 자동 병합된다.
    func makeBackgroundContext() -> NSManagedObjectContext {
        let background = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        background.persistentStoreCoordinator = persistentStoreCoordinator
        return background
    }
}
```

컨테이너는 앱 진입점에서 한 번 만들고 주입한다.

```swift
// SwiftUI 앱: App이 컨테이너를 소유하고 viewContext를 Environment로 내려준다.
@main
struct MainApp: App {
    // App 인스턴스는 앱 생명주기 동안 하나이므로 컨테이너도 한 번만 만들어진다.
    private let container = makeAppContainer()

    var body: some Scene {
        WindowGroup {
            RecordRootView()
                // 하위 뷰의 @FetchRequest와 @Environment(\.managedObjectContext)가 이 컨텍스트를 쓴다.
                .environment(\.managedObjectContext, container.viewContext)
        }
    }
}

// UIKit 앱: SceneDelegate가 컨테이너를 소유하고 첫 화면의 생성자로 넘긴다.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let container = makeAppContainer()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let root = RecordListViewController(container: container)
        window.rootViewController = UINavigationController(rootViewController: root)
        window.makeKeyAndVisible()
        self.window = window
    }
}
```

## 엔티티와 렌더링 모델 경계

화면에 값을 그리는 방법은 두 가지다.

| 방법 | 값이 있는 곳 | 동기화 |
| --- | --- | --- |
| 엔티티 속성을 직접 사용 | 엔티티 한 곳 | 필요 없음. 변경 감지 경로가 그대로 화면을 갱신한다 |
| 매핑 모델로 변환해 사용 | 엔티티와 매핑 모델 두 곳 | 엔티티에서 매핑 모델로 한 방향. 변경 감지 경로에서만 다시 만든다 |

기본은 엔티티 속성을 직접 쓰는 것이다. 아래 중 하나에 해당할 때만 매핑 모델을 만든다.

| 매핑 모델을 만드는 경우 | 예 |
| --- | --- |
| 한 행을 그리는 데 여러 엔티티나 관계를 펼쳐야 한다 | 주문 행에 고객 이름, 상품 목록 요약, 배송 상태를 함께 표시 |
| 원시값을 해석해야 화면에 쓸 수 있다 | 문자열 원시값을 enum으로 바꾸고, 해석에 실패한 행은 표시하지 않음 |
| 값을 메인 스레드 밖이나 컨텍스트 밖으로 넘겨야 한다 | 이미지 렌더링, 다른 모듈의 UI 컴포넌트에 값 전달 |
| 화면 컴포넌트가 특정 프로토콜이나 값 타입을 요구한다 | 공용 디자인 시스템 셀이 `Hashable` 구조체를 입력으로 받음 |
| 원격 데이터와 엔티티 사이의 변환이 필요하다 | 서버 응답을 엔티티에 기록하는 동기화 |

엔티티 속성 한두 개를 그대로 보여 주거나 단순한 포맷만 필요하면 매핑 모델을 만들지 않는다.
포맷은 엔티티 extension의 계산 프로퍼티(`displayTitle`, `displayAmount`)로 해결한다.

매핑 모델을 쓸 때 지킬 것:

- **값은 두 곳까지만 둔다.** 엔티티와 매핑 모델 외에 세 번째 사본을 만들지 않는다.
  - ViewModel이 매핑 모델 배열을 들고 있다가 화면이 그 배열을 다시 `@State`로 복사하는 구조가 세 번째 사본이다.
  - UIKit에서는 cell provider가 셀을 구성할 때마다 엔티티에서 매핑 모델을 만들어 넘기고 보관하지 않는 방식을 기본으로 한다. 이 경우 매핑 모델은 셀 구성 순간에만 존재하므로 사실상 값이 있는 곳은 엔티티 하나다.
- **동기화는 한 방향이다.** 매핑 모델은 엔티티에서만 만든다(`toModel()`). 매핑 모델에서 엔티티로 거꾸로 값을 복사하는 경로를 만들지 않는다.
- **갱신 시점은 변경 감지 경로 하나다.** FRC delegate 콜백, `reconfigureItems(_:)`로 다시 호출되는 cell provider, `objectWillChange`에서만 매핑 모델을 다시 만든다. 쓰기 직후에 매핑 모델을 직접 고치지 않는다.
- **변환 실패를 크래시로 만들지 않는다.** `toModel()`은 필수 값이 비었거나 원시값이 맞지 않으면 `nil`을 돌려주고, 호출하는 쪽은 빈 셀이나 빈 행으로 처리한다.
- 변환 함수(`toModel()`, `map(model:)`)는 엔티티 extension 한 곳에 둔다. 변환 규칙이 여러 화면에 흩어지면 화면마다 다른 값을 보여 준다.

넘기는 값의 종류는 경계마다 다음과 같이 정한다.

| 경계 | 넘기는 것 | 이유 |
| --- | --- | --- |
| UIKit 셀 | 엔티티 속성을 cell provider 안에서 읽어 넘기거나, 매핑 모델 | 셀은 재사용되므로 `NSManagedObject`를 프로퍼티로 보관하지 않는다 |
| SwiftUI 행, 상세 | `@ObservedObject`로 받은 엔티티, 또는 매핑 모델 | 엔티티를 받으면 속성 변경을 뷰가 직접 관찰한다. 매핑 모델을 받으면 갱신 책임은 매핑 모델을 만든 쪽에 있다 |
| 화면 사이, 스레드 사이 | `NSManagedObjectID` | 관리 객체는 자기 컨텍스트 밖에서 쓸 수 없다 |
| 외부(서버) 데이터 | 값 타입 모델 → `map(model:)`로 엔티티에 기록 | 변환 지점을 엔티티 extension 하나로 모은다 |

### 코드

```swift
// category 속성에 저장하는 원시값이다.
enum RecordCategory: String, CaseIterable, Hashable {
    case inbox, active, archived

    var displayName: String {
        switch self {
        case .inbox: "받은 항목"
        case .active: "진행 중"
        case .archived: "보관"
        }
    }
}

// 매핑 모델: 원시값(category 문자열)을 enum으로 해석해야 하므로 값 타입으로 변환한다.
// 같은 타입을 원격 데이터의 값 모델로도 쓴다. (writes.md의 "외부 데이터 동기화")
struct RecordModel: Identifiable, Hashable {
    let id: String
    let title: String
    let category: RecordCategory
    let amount: Int
    let isActive: Bool
    let updatedAt: Date
    let createdAt: Date
}

// 변환 함수는 엔티티 extension에 모은다.
extension Record {
    // 필수 값이 비었거나 enum 원시값이 맞지 않으면 nil을 돌려준다.
    func toModel() -> RecordModel? {
        guard
            let recordId,
            let title,
            let rawCategory = category,
            let category = RecordCategory(rawValue: rawCategory),
            let updatedAt, let createdAt
        else { return nil }
        return RecordModel(
            id: recordId,
            title: title,
            category: category,
            amount: Int(amount),
            isActive: isActive,
            updatedAt: updatedAt,
            createdAt: createdAt
        )
    }

    // 외부 데이터를 엔티티에 기록하는 유일한 지점이다.
    func map(model: RecordModel) {
        recordId = model.id
        title = model.title
        category = model.category.rawValue
        amount = Int32(model.amount)
        isActive = model.isActive
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }
}

// 엔티티 속성을 직접 쓰는 경우: 단순한 포맷은 매핑 모델 대신 extension의 계산 프로퍼티로 해결한다.
extension Record {
    // title은 옵셔널이므로 강제 언래핑 대신 대체 문자열을 돌려준다.
    var displayTitle: String {
        title ?? "(제목 없음)"
    }

    var displayAmount: String {
        amount.formatted(.number.grouping(.automatic))
    }
}
```

## 동시성 규칙

- 컨텍스트와 그 컨텍스트의 객체는 그 컨텍스트의 큐에서만 쓴다.
  - viewContext: 메인 스레드
  - 백그라운드 컨텍스트: `perform` 또는 `performAndWait` 블록 안
- **viewContext는 MainActor 격리 코드에서 `perform` 없이 직접 쓴다.**
  - viewContext는 main queue 컨텍스트이므로 메인 스레드가 곧 그 컨텍스트의 큐다. MainActor로 격리된 코드는 항상 메인 스레드에서 실행되므로 이미 올바른 큐 위에 있다.
  - MainActor 격리 코드: SwiftUI `View`의 `body`와 액션 클로저, `UIViewController`와 `UIView`의 메서드, `@MainActor`를 붙인 ViewModel과 함수
  - 이 코드 안에서는 `Record(context: viewContext)`로 객체를 바로 만들고, 속성을 바꾸고, `fetch`, `delete`, `save`를 직접 호출한다. `perform`으로 감싸지 않는다.
  - 이 허용은 viewContext에만 해당한다. 백그라운드 컨텍스트와 그 객체는 MainActor 코드 안에서도 반드시 `perform` 또는 `performAndWait` 안에서 쓴다. 백그라운드 컨텍스트의 큐는 메인 스레드가 아니기 때문이다.
  - 격리가 보장되지 않는 곳(백그라운드 컨텍스트의 `perform` 블록 안, `Task.detached`, 일반 클래스의 `nonisolated` 메서드)에서는 viewContext를 직접 쓰지 않는다. `Task { @MainActor in ... }`로 넘기거나 `viewContext.perform`을 쓴다.
  - 비용이 큰 작업(수백 건 이상의 생성과 수정, 큰 fetch)은 MainActor 코드라도 viewContext에서 하지 않는다. 메인 스레드가 멈춘다. 백그라운드 컨텍스트로 옮긴다.
- 스레드나 컨텍스트 경계를 넘길 때는 objectID나 값 타입만 넘긴다. 받는 쪽에서 `existingObject(with:)`로 다시 얻는다.
- 관리 객체의 Combine publisher(`publisher(for: \.title)`)를 UI에 연결할 때는 `.receive(on: DispatchQueue.main)`을 붙인다. 객체가 백그라운드 컨텍스트 소속일 수 있다.
- `UndoManager`의 `undo()`, `redo()`도 컨텍스트 큐에서 호출한다.
- 백그라운드 작업이 끝난 뒤 UI를 건드려야 하면 `Task { @MainActor in ... }`로 넘긴다.

### 코드

```swift
// MainActor 격리 코드에서는 viewContext 객체를 perform 없이 직접 만들고 저장한다.
@MainActor
func addRecord(in viewContext: NSManagedObjectContext) {
    // recordId, createdAt, updatedAt은 awakeFromInsert가 채운다.
    let record = Record(context: viewContext)
    record.title = "새 항목"
    record.category = RecordCategory.inbox.rawValue
    viewContext.saveOrNotify("추가")
}

// 같은 MainActor 코드라도 백그라운드 컨텍스트는 perform 안에서만 쓴다.
@MainActor
func addRecordInBackground(container: NSPersistentContainer) {
    let background = container.newBackgroundContext()
    background.perform {
        let record = Record(context: background)
        record.title = "새 항목"
        do {
            try background.save()
        } catch {
            background.rollback()
            showError("[추가 실패] \(error.localizedDescription)")
        }
    }
}

// 백그라운드 컨텍스트 소속 객체의 KVO publisher는 메인 스레드에서 받는다.
object
    .publisher(for: \.title)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] value in
        self?.textField.text = value
    }
    .store(in: &subscriptions)

// undo, redo는 스레드 안전하지 않으므로 컨텍스트 큐에서 실행한다.
@objc func undoButtonTapped() {
    guard let um = context.undoManager, um.canUndo else { return }
    context.perform {
        um.undo()
    }
}

// 백그라운드 작업이 끝나면 메인 액터로 넘겨 UI 경로를 실행한다.
let context = container.newBackgroundContext()
context.perform { [weak self] in
    do {
        _ = try context.execute(request)
        Task { @MainActor [weak self] in
            self?.refreshController()
        }
    } catch {
        showError("작업 실패: \(error.localizedDescription)")
    }
}
```

## 에러 처리 방침

| 실패 | 처리 |
| --- | --- |
| 모델 로드, 스토어 로드 실패 | `fatalError`. 앱이 동작할 수 없는 상태다 |
| 저장 실패 | `rollback()` 후 사용자에게 알림. 되돌리지 않으면 실패한 변경이 남아 다음 저장도 실패한다 |
| fetch, 객체 복원 실패 | 사용자에게 알리고 대체 화면이나 빈 상태를 보여 준다 |
| 배치 요청 실패 | 사용자에게 알림. 컨텍스트에 남는 변경이 없으므로 rollback은 필요 없다 |

- 뷰와 뷰컨트롤러에서 `try!`로 저장하지 않는다. 유니크 제약 충돌이나 검증 실패로 앱이 종료된다.
- 저장은 `hasChanges`가 true일 때만 한다.
- 실패를 삼키지 않는다. 사용자에게 알리거나 로그로 남긴다.

### 코드

```swift
// 사용자에게 실패를 알리는 함수다. 앱의 알림 수단(토스트, 알럿, 배너)으로 구현한다.
// 다른 코드 블록의 showError(_:)도 이 함수를 가리킨다.
func showError(_ message: String) { ... }

extension NSManagedObjectContext {
    // 변경이 있을 때만 저장하고, 실패하면 rollback한 뒤 사용자에게 알린다.
    // 되돌리지 않으면 실패한 변경이 컨텍스트에 남아 다음 저장도 계속 실패한다.
    @discardableResult
    func saveOrNotify(_ label: String) -> Bool {
        guard hasChanges else { return true }
        do {
            try save()
            return true
        } catch {
            rollback()
            showError("[\(label) 실패] \(error.localizedDescription)")
            return false
        }
    }
}
```

## 삭제된 객체 접근 방지

- `object(with:)`는 존재하지 않는 ID에도 폴트 객체를 돌려준다. 속성을 읽는 순간 크래시한다.
- `existingObject(with:)`는 스토어에 없으면 에러를 던진다. ID의 출처를 확신할 수 없으면 이것을 쓴다.
  - 화면 이동으로 받은 ID, 다른 컨텍스트에서 넘어온 ID, 배치 삭제가 일어날 수 있는 목록
- FRC가 방금 돌려준 ID를 같은 viewContext에서 바로 쓰는 경우에는 `object(with:)`도 된다.
- 객체를 들고 있는 뷰는 속성을 읽기 전에 `!isDeleted && managedObjectContext != nil`을 확인한다.
- 배치 삭제 결과는 `NSDeletedObjectsKey`로 병합한다. `NSUpdatedObjectsKey`로 병합하면 이미 지워진 행에 refresh가 걸려 폴트를 채우지 못한다.

### 코드

```swift
extension Record {
    // SwiftUI는 삭제 애니메이션이 끝나기 전까지 행 뷰를 한 번 더 그릴 수 있다.
    // 그 시점에 속성을 읽으면 폴트 해소에 실패해 크래시할 수 있으므로 뷰는 이 값을 먼저 확인한다.
    var isUsable: Bool {
        !isDeleted && managedObjectContext != nil
    }
}

// 배치 삭제가 일어나는 목록의 cell provider는 existingObject(with:)로 객체를 얻는다.
if let entity = try? container?.viewContext.existingObject(with: objectId) as? Record,
   let model = entity.toModel() {
    cell.configure(model)
}
```
