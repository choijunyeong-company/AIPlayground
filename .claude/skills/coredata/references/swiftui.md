# SwiftUI: 책임 구성 명세

SwiftUI에서는 UIKit의 ①~④ 책임이 property wrapper와 `ObservableObject`에 흡수된다.
개발자가 직접 쓰는 코드는 쿼리 선언, 행 뷰의 관찰 선언, 쓰기 경로뿐이다.
테스트나 재사용 때문에 이 책임을 뷰 밖으로 옮겨야 하면 ViewModel이 컨테이너를 주입받아 맡는다. ("ViewModel로 옮길 때" 섹션)

## UIKit 책임과의 대응

| UIKit 책임 | SwiftUI에서 맡는 곳 (뷰 중심) | SwiftUI에서 맡는 곳 (ViewModel 중심) |
| --- | --- | --- |
| 스택 제공 | 앱 진입점에서 만든 viewContext를 Environment(`\.managedObjectContext`)로 주입받음 | 앱 진입점에서 만든 컨테이너를 ViewModel 생성자로 주입받음 |
| ① 쿼리 정의 | `@FetchRequest`, `@SectionedFetchRequest` 선언 | ViewModel이 FRC를 만듦 |
| ② 변경 감지 (삽입, 삭제, 순서) | property wrapper 내부의 FRC | ViewModel의 FRC delegate |
| ② 변경 감지 (기존 객체 속성) | 행 뷰의 `@ObservedObject` (`NSManagedObject`는 `ObservableObject`) | 행 뷰의 `@ObservedObject`, 또는 FRC delegate에서 매핑 모델을 다시 만듦 |
| ③ UI 업데이트 매핑 | SwiftUI의 diff. `animation:` 인자로 애니메이션만 지정 | SwiftUI의 diff. `@Published` 값이 바뀌면 다시 그림 |
| ④ 항목 표시 | 행 뷰가 엔티티 속성이나 extension의 표시용 프로퍼티를 직접 읽음 | 행 뷰가 엔티티를 관찰하거나, ViewModel이 만든 매핑 모델을 받음 |
| 쓰기 | Environment의 viewContext, 같은 코디네이터의 백그라운드 컨텍스트, 자식 컨텍스트 | ViewModel이 주입받은 컨테이너의 viewContext와 백그라운드 컨텍스트 |

## 규칙

### 스택과 주입

- 컨테이너는 앱 진입점(`App`, UIKit 앱이면 `SceneDelegate`)에서 한 번 만든다. 만드는 코드는 stack.md의 "컨테이너와 컨텍스트 역할"에 있다.
- 뷰는 컨테이너를 직접 만들거나 전역 정적 프로퍼티로 꺼내 쓰지 않는다. 둘 중 하나로 주입받는다.

| 주입 방법 | 쓸 때 | 받는 쪽 |
| --- | --- | --- |
| Environment(`\.managedObjectContext`) | `@FetchRequest`로 충분한 화면 | 하위의 `@FetchRequest`, `@SectionedFetchRequest`, `@Environment(\.managedObjectContext)` |
| ViewModel 생성자 | 쿼리나 쓰기 로직을 테스트하거나 여러 화면에서 재사용할 때 | `@StateObject`로 만든 ViewModel |

- Environment로 받은 viewContext에서 백그라운드 작업이 필요하면 같은 `persistentStoreCoordinator`를 쓰는 private queue 컨텍스트를 만든다. 코드는 stack.md의 `makeBackgroundContext()`에 있다.
- 시트와 `UIHostingController`는 새 환경을 만들 수 있으므로 `.environment(\.managedObjectContext, context)`를 다시 붙인다.
- `@StateObject`로 ViewModel을 만들 때는 `init`에서 `_viewModel = StateObject(wrappedValue:)`로 한 번만 만든다. `body` 안에서 ViewModel을 만들면 다시 그릴 때마다 FRC가 새로 만들어진다.

#### 코드

```swift
// 앱 진입점이 컨테이너를 소유하고 viewContext를 Environment로 내려준다. (stack.md의 MainApp)
WindowGroup {
    RecordRootView()
        .environment(\.managedObjectContext, container.viewContext)
}

struct RecordRootView: View {
    // Environment로 주입받은 viewContext다. 뷰가 컨테이너를 직접 만들지 않는다.
    @Environment(\.managedObjectContext) private var context
    // 앱이 백그라운드로 내려갈 때 저장하지 않은 변경을 저장하기 위해 관찰한다.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RecordListView()
            .task { seedIfNeeded() }
            .onChange(of: scenePhase) { _, phase in
                // Toggle로 바꾼 값이 유실되지 않게 하는 안전망이다.
                guard phase == .background else { return }
                context.saveOrNotify("백그라운드 진입 시 저장")
            }
    }
}

// 시트에는 컨텍스트를 다시 주입한다.
.sheet(item: $editingRecord) { record in
    RecordEditSheet(record: record)
        .environment(\.managedObjectContext, context)
}
```

### 쿼리와 동적 조건

- 조건을 바꿀 때는 `FetchedResults`의 프로퍼티에 대입한다. `records.nsPredicate = ...`, `records.sortDescriptors = ...`처럼 쓴다.
  - 세터가 `nonmutating`이라 그대로 대입할 수 있다. 내부 FRC가 즉시 다시 fetch한다.
  - `$records.sortDescriptors`는 Binding이라 Picker에 바로 연결할 수 있다.
- 조건을 `@State`로 두고 `init`에서 `FetchRequest`를 새로 만드는 방식은 쓰지 않는다. 뷰가 재생성될 때마다 FRC가 새로 만들어진다.
- `@SectionedFetchRequest`의 `sectionIdentifier`는 첫 번째 정렬 기준과 같아야 한다.

#### 코드

```swift
struct RecordListView: View {
    private enum SortOption: String, CaseIterable, Identifiable {
        case title = "제목"
        case amountAscending = "금액 낮은순"
        case amountDescending = "금액 높은순"
        var id: String { rawValue }

        var descriptors: [SortDescriptor<Record>] {
            switch self {
            case .title: [SortDescriptor(\Record.title)]
            case .amountAscending: [SortDescriptor(\Record.amount), SortDescriptor(\Record.title)]
            case .amountDescending: [SortDescriptor(\Record.amount, order: .reverse), SortDescriptor(\Record.title)]
            }
        }
    }

    @Environment(\.managedObjectContext) private var context
    // 행을 탭하면 objectID만 넘긴다. 화면 이동 방식은 상위가 정한다.
    var onSelectRecord: (NSManagedObjectID) -> Void = { _ in }
    // animation을 지정하면 삽입, 삭제, 정렬 변경이 애니메이션으로 반영된다.
    @FetchRequest(sortDescriptors: [SortDescriptor(\Record.title)], animation: .default)
    private var records: FetchedResults<Record>

    // 검색어는 스토어에 저장하지 않는 순수 UI 상태라 @State로 둔다.
    @State private var query = ""

    var body: some View {
        List {
            ForEach(records) { record in
                RecordRowView(record: record)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectRecord(record.objectID) }
            }
        }
        .searchable(text: $query, prompt: "제목 검색")
        .onChange(of: query) { _, newValue in
            // 방식 1: FetchedResults의 프로퍼티에 직접 대입한다.
            // 대입 즉시 내부 FRC가 다시 fetch하고, 같은 렌더링 트랜잭션에서 body가 호출된다.
            records.nsPredicate = newValue.isEmpty
                ? nil
                : NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(Record.title), newValue)
        }
        .toolbar {
            Menu("작업", systemImage: "ellipsis.circle") {
                // 방식 2: $records.sortDescriptors Binding을 Picker에 직접 연결한다.
                Picker("정렬", selection: $records.sortDescriptors) {
                    ForEach(SortOption.allCases) { Text($0.rawValue).tag($0.descriptors) }
                }
            }
        }
    }
}

struct SectionedRecordListView: View {
    @SectionedFetchRequest(
        sectionIdentifier: \Record.isActive,
        sortDescriptors: [
            // 첫 번째 정렬 기준이 sectionIdentifier와 같아야 같은 섹션이 한 번만 나타난다.
            SortDescriptor(\Record.isActive, order: .reverse),
            SortDescriptor(\Record.title),
        ],
        animation: .default
    )
    private var sections: SectionedFetchResults<Bool, Record>

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    // 행에서 isActive를 바꾸면 그 객체는 다른 섹션으로 애니메이션과 함께 이동한다.
                    ForEach(section) { record in
                        RecordRowView(record: record)
                    }
                } header: {
                    Text("\(section.id ? "활성" : "비활성") \(section.count)건")
                }
            }
        }
    }
}
```

### 객체 관찰과 항목 표시

행 뷰가 값을 받는 방법은 둘 중 하나다. 판단 기준은 stack.md의 "엔티티와 렌더링 모델 경계"를 본다.

| 방법 | 행 뷰가 받는 것 | 속성 변경을 반영하는 쪽 |
| --- | --- | --- |
| 엔티티 속성을 직접 사용 (기본) | `@ObservedObject var record: Record` | 행 뷰 자신. 엔티티의 `objectWillChange`를 관찰한다 |
| 매핑 모델 사용 | `let row: RecordRow` (값 타입) | 매핑 모델을 만든 ViewModel. FRC delegate에서 매핑 모델 배열을 다시 만든다 |

- 엔티티를 받을 때는 반드시 `@ObservedObject`로 받는다. `let record: Record`로 받으면 속성이 바뀌어도 다시 그려지지 않는다.
- `@ObservedObject`로 받으면 속성 변경 시 해당 행만 다시 그려지고 목록 뷰의 `body`는 호출되지 않는다. 변경 주체가 같은 화면의 Toggle이든, 백그라운드 병합이든, 배치 업데이트 병합이든 같다.
- 매핑 모델을 받을 때는 그 매핑 모델에 `NSManagedObjectID`를 담는다. 행에서 값을 바꾸거나 상세 화면으로 이동할 때 이 ID로 엔티티를 다시 얻는다.
- 매핑 모델을 받은 행 뷰는 그 값을 `@State`로 다시 복사하지 않는다. 엔티티, ViewModel의 매핑 모델, `@State` 사본으로 값이 세 곳이 된다.
- 엔티티의 옵셔널 속성은 엔티티 extension에 표시용 프로퍼티를 두어 처리한다. 뷰에서 강제 언래핑하지 않는다.
- `hasChanges`는 관찰 가능한 값이 아니다. 저장되지 않은 변경 수를 보여 주려면 `NSManagedObjectContext.didChangeObjectsNotification`을 `onReceive`로 받는다.
- 저장 결과를 알고 싶으면 `didSaveObjectIDsNotification`을 받는다. 다른 스택의 저장을 걸러내려면 `persistentStoreCoordinator`가 같은지 비교한다.

#### 코드

매핑 모델을 쓰는 행 뷰는 아래 "ViewModel로 옮길 때"의 코드에 있다.

```swift
// 엔티티 속성을 직접 쓰는 행 뷰
struct RecordRowView: View {
    @Environment(\.managedObjectContext) private var context
    // NSManagedObject는 ObservableObject다. 관리 속성이 바뀌면 objectWillChange가 발행되어 이 뷰만 다시 그려진다.
    @ObservedObject var record: Record

    var body: some View {
        // 삭제 애니메이션 도중 한 번 더 그려질 때 속성을 읽으면 폴트 해소 실패로 크래시할 수 있다.
        if record.isUsable {
            content
        } else {
            EmptyView()
        }
    }

    private var content: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(record.displayTitle)
                Text(record.displayAmount)
            }
            Spacer()
            // $record.isActive는 ObservedObject.Wrapper가 만드는 Binding이다.
            Toggle(isOn: $record.isActive) { Text("활성") }
                .labelsHidden()
        }
        .onChange(of: record.isActive) { _, _ in
            // Binding으로 바꾼 값은 자동 저장되지 않으므로 여기서 저장한다.
            // 백그라운드 병합으로 바뀐 경우에는 hasChanges가 false라 아무 일도 하지 않는다.
            context.saveOrNotify("활성 상태 저장")
        }
    }
}

// 목록 뷰: 저장되지 않은 변경 수와 저장 결과를 알림으로 받는다.
@State private var pendingChangeCount = 0

.onReceive(NotificationCenter.default.publisher(for: NSManagedObjectContext.didChangeObjectsNotification, object: context)) { _ in
    pendingChangeCount = context.insertedObjects.count + context.updatedObjects.count + context.deletedObjects.count
}
.onReceive(NotificationCenter.default.publisher(for: NSManagedObjectContext.didSaveObjectIDsNotification)) { notification in
    reportSave(notification)
}

// 알림을 보낸 컨텍스트가 같은 코디네이터에 속하는지 확인해 다른 스택의 저장은 무시한다.
func reportSave(_ notification: Notification) {
    guard
        let sender = notification.object as? NSManagedObjectContext,
        sender.persistentStoreCoordinator === context.persistentStoreCoordinator
    else { return }
    let inserted = (notification.userInfo?[NSInsertedObjectIDsKey] as? Set<NSManagedObjectID>)?.count ?? 0
    let updated = (notification.userInfo?[NSUpdatedObjectIDsKey] as? Set<NSManagedObjectID>)?.count ?? 0
    let deleted = (notification.userInfo?[NSDeletedObjectIDsKey] as? Set<NSManagedObjectID>)?.count ?? 0
    let origin = sender === context ? "뷰 컨텍스트" : "다른 컨텍스트"
    print("[\(origin) 저장] 삽입 \(inserted), 수정 \(updated), 삭제 \(deleted)")
}
```

### 쓰기와 저장 시점

- **View 안에서는 Environment의 viewContext로 객체를 직접 만들고 고친다.** SwiftUI `View`는 MainActor로 격리되어 있고 viewContext는 main queue 컨텍스트이므로, `Record(context: context)`, 속성 대입, `delete`, `save`를 `perform` 없이 바로 호출한다. `@MainActor` ViewModel의 메서드도 같다. 이 허용은 viewContext에만 해당하며, 백그라운드 컨텍스트는 View 안에서도 `perform` 안에서만 쓴다. (stack.md의 "동시성 규칙")
- Binding으로 속성을 바꿔도 저장은 자동으로 되지 않는다. `onChange`에서 `saveOrNotify`를 호출한다.
- 앱이 백그라운드로 갈 때 `scenePhase`를 보고 남은 변경을 저장한다.
- 시드 데이터는 개수를 먼저 세고 비어 있을 때만 넣는다. 넣은 뒤에는 `undoManager?.removeAllActions()`로 Undo 대상에서 뺀다.
- 무거운 쓰기(일괄 수정, 배치 요청)는 백그라운드 컨텍스트에서 한다. 코드는 writes.md의 "배치 요청"에 있다.

#### 코드

```swift
// 아래 함수는 모두 View 안에 있어 MainActor로 격리된다.
// context는 Environment로 받은 viewContext이므로 perform 없이 객체를 만들고 저장한다.

// 스토어가 비어 있을 때만 시드 데이터를 넣는다.
// 이미 데이터가 있는데 다시 넣으면 같은 데이터가 중복되므로 개수를 먼저 센다.
// 100건 정도는 viewContext에서 바로 넣어도 된다. 수천 건 이상이면 writes.md의 배치 삽입을 쓴다.
private func seedIfNeeded() {
    do {
        let count = try context.count(for: Record.fetchRequest())
        guard count == 0 else { return }
        for index in 0..<100 {
            // recordId, createdAt, updatedAt은 awakeFromInsert가 채운다.
            let record = Record(context: context)
            record.title = "Record_\(index)"
            record.category = RecordCategory.allCases[index % RecordCategory.allCases.count].rawValue
            record.amount = Int32(index * 1_000)
            record.isActive = index.isMultiple(of: 2)
        }
        // 시드 삽입은 Undo 대상에서 제외한다.
        context.undoManager?.removeAllActions()
        context.saveOrNotify("초기 데이터 저장")
    } catch {
        showError("[초기 데이터 확인 실패] \(error.localizedDescription)")
    }
}

// MainActor 격리 코드에서 viewContext 객체를 직접 만든다. perform으로 감싸지 않는다.
// 저장만 하고 목록에 직접 넣지 않는다. 목록 갱신은 FRC와 행 뷰가 맡는다.
func addRecord() {
    // recordId, createdAt, updatedAt은 awakeFromInsert가 채운다.
    let record = Record(context: context)
    record.title = "새 항목"
    record.category = RecordCategory.inbox.rawValue
    record.amount = Int32.random(in: 1...50) * 1_000
    record.isActive = true
    context.saveOrNotify("추가")
}

// 삭제된 객체는 저장 전까지 isDeleted가 true다.
func delete(_ record: Record) {
    context.delete(record)
    context.saveOrNotify("삭제")
}

// 화면에 보이는 객체의 속성을 한 번에 바꾼다. 각 행이 자기 객체를 관찰하므로 바뀐 행만 다시 그려진다.
func deactivateAll() {
    records.forEach { $0.isActive = false }
    context.saveOrNotify("전체 비활성")
}

enum RecordError: LocalizedError {
    case objectNotFound

    var errorDescription: String? {
        switch self {
        case .objectNotFound: "해당 objectID의 Record를 찾을 수 없습니다."
        }
    }
}
```

### 화면 이동과 삭제된 객체

- 상세 화면에는 objectID만 넘기고 `existingObject(with:)`로 복원한다. 실패하면 대체 화면을 보여 준다.
- 행 뷰는 `body`에서 속성을 읽기 전에 `!isDeleted && managedObjectContext != nil`(`Record.isUsable`)을 확인한다. 삭제 애니메이션 중에 한 번 더 그려질 때 폴트 해소에 실패해 크래시할 수 있기 때문이다.

#### 코드

```swift
struct RecordDetailView: View {
    @Environment(\.managedObjectContext) private var context
    let objectId: NSManagedObjectID
    @State private var record: Record?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let record, record.isUsable {
                // 내부 뷰가 @ObservedObject로 관찰하므로 목록 변경이나 백그라운드 병합도 이 화면에 반영된다.
                RecordDetailContent(record: record)
            } else if loadFailed {
                ContentUnavailableView("객체를 찾을 수 없습니다.", systemImage: "questionmark.folder")
            } else {
                ContentUnavailableView("삭제된 객체입니다.", systemImage: "trash")
            }
        }
        .task(id: objectId) { load() }
    }

    private func load() {
        do {
            // object(with:)는 없는 ID에도 폴트를 돌려주므로 existingObject(with:)로 복원한다.
            guard let restored = try context.existingObject(with: objectId) as? Record else {
                throw RecordError.objectNotFound
            }
            // @State에 담는 것은 엔티티 참조다. 값을 복사한 것이 아니므로 사본이 생기지 않는다.
            record = restored
        } catch {
            loadFailed = true
            showError("[객체 복원 실패] \(error.localizedDescription)")
        }
    }
}

private struct RecordDetailContent: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var record: Record

    var body: some View {
        Form {
            LabeledContent("제목", value: record.displayTitle)
            LabeledContent("금액", value: record.displayAmount)
            Button("금액 1,000 증가") {
                record.amount += 1_000
                context.saveOrNotify("금액 저장")
            }
            Button("변경 폐기") {
                // 저장되지 않은 변경을 버리고 폴트로 돌린다. 다음 접근에서 스토어 값으로 다시 로드된다.
                context.refresh(record, mergeChanges: false)
            }
        }
    }
}
```

## ViewModel로 옮길 때

`@FetchRequest`는 쿼리, 변경 감지, 매핑을 뷰에 묶는다. 대부분은 이대로 충분하다.
테스트나 재사용 때문에 뷰 밖으로 옮겨야 하면 다음 기준을 따른다.

- ViewModel은 생성자로 컨테이너를 받는다. 컨테이너를 직접 만들거나 전역에서 꺼내지 않는다. 테스트에서는 메모리 스토어(`/dev/null` URL) 컨테이너를 넘긴다.
- ViewModel이 FRC를 소유하고 delegate도 직접 구현한다. FRC를 뷰와 ViewModel이 나눠 갖지 않는다.
- 결과는 `[NSManagedObjectID]`나 매핑 모델 배열 하나로 노출한다. 이 배열은 FRC delegate에서만 갱신한다.
  - `[NSManagedObjectID]`를 노출하면 행 뷰는 ID로 엔티티를 얻어 `@ObservedObject`로 관찰한다. 값이 있는 곳은 엔티티 하나다.
  - 매핑 모델 배열을 노출하면 값이 있는 곳은 엔티티와 매핑 모델 두 곳이다. FRC는 결과에 속한 객체의 속성이 바뀌어도 delegate를 호출하므로, 그때 배열을 다시 만들면 속성 변경도 반영된다.
- 뷰는 ViewModel의 배열을 `@State`로 복사하지 않는다. 세 번째 사본이 된다.
- 쓰기 함수는 저장만 하고 결과 배열을 직접 고치지 않는다. 배열은 저장 후 FRC delegate가 다시 만든다.
- 매핑 모델에는 `NSManagedObjectID`를 담는다. 쓰기와 화면 이동은 이 ID로 엔티티를 다시 얻어서 한다.

#### 코드

```swift
// 매핑 모델: 행에 필요한 값과 쓰기에 쓸 objectID를 담는다.
struct RecordRow: Identifiable, Hashable {
    let id: NSManagedObjectID
    let title: String
    let amount: String
    let isActive: Bool
}

extension Record {
    // 매핑 모델은 엔티티에서만 만든다. 거꾸로 매핑 모델에서 엔티티로 값을 복사하지 않는다.
    func toRow() -> RecordRow {
        RecordRow(id: objectID, title: displayTitle, amount: displayAmount, isActive: isActive)
    }
}

@MainActor
final class RecordListViewModel: NSObject, ObservableObject {
    // 값이 있는 곳은 엔티티와 이 배열 두 곳이다. 이 배열은 FRC delegate에서만 바뀐다.
    @Published private(set) var rows: [RecordRow] = []

    private let container: NSPersistentContainer
    private let controller: NSFetchedResultsController<Record>

    // 컨테이너는 앱 진입점에서 만든 것을 주입받는다.
    init(container: NSPersistentContainer) {
        self.container = container
        let request = Record.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Record.title, ascending: true)]
        controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        super.init()
        controller.delegate = self
        do {
            try controller.performFetch()
            rows = (controller.fetchedObjects ?? []).map { $0.toRow() }
        } catch {
            showError("[목록 조회 실패] \(error.localizedDescription)")
        }
    }

    // 클래스가 @MainActor로 격리되어 있으므로 viewContext는 perform 없이 직접 쓴다.
    // 쓰기는 objectID로 엔티티를 얻어 고치고 저장만 한다. rows는 직접 고치지 않는다.
    func setActive(_ isActive: Bool, for id: NSManagedObjectID) {
        let context = container.viewContext
        guard let record = try? context.existingObject(with: id) as? Record else { return }
        record.isActive = isActive
        context.saveOrNotify("활성 상태 저장")
    }

    // 무거운 작업은 주입받은 컨테이너의 백그라운드 컨텍스트에서 한다.
    // MainActor 클래스 안이라도 백그라운드 컨텍스트는 perform 안에서만 쓴다.
    func activateAll() {
        let background = container.newBackgroundContext()
        background.perform {
            do {
                let request = Record.fetchRequest()
                request.predicate = NSPredicate(format: "%K == NO", #keyPath(Record.isActive))
                try background.fetch(request).forEach { $0.isActive = true }
                try background.save()
                // 저장 결과는 automaticallyMergesChangesFromParent로 viewContext에 병합되고,
                // FRC delegate가 호출되어 rows가 다시 만들어진다.
            } catch {
                background.rollback()
                showError("[백그라운드 저장 실패] \(error.localizedDescription)")
            }
        }
    }
}

extension RecordListViewModel: NSFetchedResultsControllerDelegate {
    // 삽입, 삭제, 순서 변경뿐 아니라 결과에 속한 객체의 속성 변경에도 호출된다.
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        // FRC가 viewContext에 붙어 있으므로 이 콜백은 메인 스레드에서 호출된다.
        MainActor.assumeIsolated {
            rows = (self.controller.fetchedObjects ?? []).map { $0.toRow() }
        }
    }
}

struct RecordListScreen: View {
    @StateObject private var viewModel: RecordListViewModel

    // 상위에서 받은 컨테이너로 ViewModel을 한 번만 만든다.
    init(container: NSPersistentContainer) {
        _viewModel = StateObject(wrappedValue: RecordListViewModel(container: container))
    }

    var body: some View {
        List(viewModel.rows) { row in
            // 행은 매핑 모델을 그대로 그린다. @State로 다시 복사하지 않는다.
            HStack {
                VStack(alignment: .leading) {
                    Text(row.title)
                    Text(row.amount)
                }
                Spacer()
                Toggle("활성", isOn: Binding(
                    get: { row.isActive },
                    // 바뀐 값은 ViewModel을 거쳐 엔티티에 쓴다. 화면 갱신은 FRC delegate가 맡는다.
                    set: { viewModel.setActive($0, for: row.id) }
                ))
                .labelsHidden()
            }
        }
        .toolbar {
            Button("전체 활성화") { viewModel.activateAll() }
        }
    }
}
```
