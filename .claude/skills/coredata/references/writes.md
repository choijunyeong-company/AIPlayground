# 쓰기 경로: 편집, Undo/Redo, 배치, 동기화, refresh

모든 쓰기는 "저장하거나 병합한다 → viewContext가 변경을 받는다 → 변경 감지가 UI를 갱신한다" 순서로 끝난다.
쓰기 코드는 목록이나 화면 상태를 직접 고치지 않는다.

## 편집 경로

```
목록 → objectID 전달 → 편집용 컨텍스트에서 객체 획득 → 편집(이 객체가 임시 상태) → 저장 또는 폐기
```

| 단계 | UIKit (`RecordEditViewController`) | SwiftUI (`RecordEditSheet`) |
| --- | --- | --- |
| 편집용 컨텍스트 | `container.newBackgroundContext()` | `parent = viewContext`인 자식 컨텍스트 |
| 객체 획득 | `existingObject(with:)`, ID가 없으면 새로 생성 | `existingObject(with:)` |
| 편집 중 UI 반영 | 객체의 KVO publisher를 구독해 입력창과 버튼 갱신 | 객체를 `@ObservedObject`로 관찰 |
| 저장 | `context.save()` → 자동 병합으로 viewContext 반영 | `child.save()` 후 `parent.save()` |
| 취소 | `context.rollback()` | 시트를 닫으면 자식 컨텍스트와 함께 폐기 |

- 편집 화면은 입력값을 별도 변수에 모으지 않는다. 입력은 곧바로 편집용 컨텍스트의 객체에 쓴다. 저장 버튼 활성화 같은 판단도 그 객체(`hasChanges`, 필수 값)를 보고 한다.
- 편집용 컨텍스트에서 바꾼 값은 저장 전까지 목록 화면에 보이지 않는다. 목록은 viewContext만 보기 때문이다.
- 자식 컨텍스트의 `save()`는 부모 메모리로 올리기만 한다. 스토어에 쓰려면 부모도 저장해야 한다.
- 새 객체를 만들었다가 취소하는 경우에도 rollback이나 컨텍스트 폐기로 끝난다. viewContext에는 흔적이 남지 않는다.

### 코드: UIKit 편집 화면

`undoGroup(name:task:)`와 `UndoState`는 아래 "Undo/Redo" 코드에 있다.

```swift
final class RecordEditViewController: UIViewController {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let object: Record
    private let undoState: UndoState
    private var isNewObject = false
    private var subscriptions: Set<AnyCancellable> = []

    init(container: NSPersistentContainer, objectId: NSManagedObjectID? = nil) {
        self.container = container
        self.context = container.newBackgroundContext()
        let undoManager = UndoManager()
        // 백그라운드 컨텍스트 큐에는 런루프가 없으므로 자동 그룹핑을 끄고 그룹을 직접 관리한다.
        // true로 두고 undo를 실행하면 열린 그룹이 없어 크래시한다.
        undoManager.groupsByEvent = false
        context.undoManager = undoManager
        self.undoState = UndoState(undoManager: undoManager)
        if
            let objectId,
            let object = try? context.existingObject(with: objectId) as? Record {
            self.object = object
        } else {
            // ID가 없으면 편집용 컨텍스트 안에서 새 객체를 만든다. 취소하면 rollback으로 사라진다.
            self.object = Record(context: context)
            self.isNewObject = true
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        // 입력창과 버튼은 편집 중인 객체를 구독해 갱신한다. 별도 입력 변수를 두지 않는다.
        subscriptions = [
            object.publisher(for: \.title)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    self?.textField.text = value
                    self?.checkConfirmation()
                },
            object.publisher(for: \.category)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.checkConfirmation() },
            undoState.$canRedo.assign(to: \.isEnabled, on: redoButton),
            undoState.$canUndo.assign(to: \.isEnabled, on: undoButton),
        ]
    }
}

private extension RecordEditViewController {
    // 저장 버튼 활성화도 편집 중인 객체의 값과 hasChanges로 판단한다.
    func checkConfirmation() {
        let isInputValid = if
            let title = object.title,
            object.category != nil { !title.isEmpty }
        else { false }
        saveButton.isEnabled = isInputValid && object.hasChanges
    }

    // 입력은 곧바로 편집용 컨텍스트의 객체에 쓴다.
    @objc func textFieldDidChange(_ textField: UITextField) {
        let text = textField.text
        undoGroup(name: "Title") { [weak self] in
            self?.object.title = text
        }
    }

    // 저장하면 automaticallyMergesChangesFromParent로 viewContext에 병합되고 FRC가 목록을 갱신한다.
    @objc func saveButtonTapped() {
        context.performAndWait {
            do {
                object.updatedAt = .now
                try context.save()
            } catch {
                showError(error.localizedDescription)
            }
        }
        dismiss(animated: true)
    }

    @objc func closeButtonTapped() {
        context.performAndWait {
            context.rollback()
        }
        dismiss(animated: true)
    }

    @objc func deleteButtonTapped() {
        context.performAndWait {
            do {
                context.delete(object)
                try context.save()
            } catch {
                showError(error.localizedDescription)
            }
        }
        dismiss(animated: true)
    }
}
```

### 코드: SwiftUI 편집 시트

```swift
struct RecordEditSheet: View {
    @Environment(\.managedObjectContext) private var parentContext
    @Environment(\.dismiss) private var dismiss
    let record: Record
    @State private var childContext: NSManagedObjectContext?
    @State private var draft: Record?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    RecordEditForm(draft: draft)
                } else {
                    ContentUnavailableView("편집할 객체를 불러오지 못했습니다.", systemImage: "exclamationmark.triangle")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // 시트를 닫으면 자식 컨텍스트가 해제되어 변경이 사라진다. 부모는 아무것도 모른다.
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(draft == nil)
                }
            }
        }
        .onAppear { prepareDraft() }
    }

    // 자식 컨텍스트는 부모 메모리에서 값을 읽으므로 부모의 저장되지 않은 변경도 함께 보인다.
    private func prepareDraft() {
        guard draft == nil else { return }
        let child = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        child.parent = parentContext
        do {
            guard let object = try child.existingObject(with: record.objectID) as? Record else {
                throw RecordError.objectNotFound
            }
            childContext = child
            draft = object
        } catch {
            showError("[편집 준비 실패] \(error.localizedDescription)")
        }
    }

    private func save() {
        guard let childContext else { return }
        // 1단계: 자식에서 부모 메모리로. 2단계: 부모에서 스토어로.
        guard childContext.saveOrNotify("자식 컨텍스트 저장") else { return }
        guard parentContext.saveOrNotify("부모 컨텍스트 저장") else { return }
        dismiss()
    }
}

// 자식 컨텍스트의 객체를 관찰한다. 부모 객체와 objectID만 같고 인스턴스는 다르다.
private struct RecordEditForm: View {
    @ObservedObject var draft: Record

    var body: some View {
        Form {
            TextField("제목", text: Binding(
                get: { draft.title ?? "" },
                set: { draft.title = $0 }
            ))
            Stepper("금액 \(draft.displayAmount)", value: $draft.amount, in: 0...1_000_000, step: 500)
            Toggle("활성", isOn: $draft.isActive)
        }
    }
}
```

## Undo/Redo

- `UndoManager`는 편집이 일어나는 컨텍스트에 붙인다.
  - UIKit 편집 화면: 편집용 백그라운드 컨텍스트
  - SwiftUI 목록: viewContext
- Undo 가능 여부 같은 UI 상태는 따로 계산하지 않는다. `UndoManager` 알림(`NSUndoManagerDidCloseUndoGroup`, `NSUndoManagerDidUndoChange`, `NSUndoManagerDidRedoChange`)을 받아 `canUndo`, `canRedo`를 다시 읽는다.
- 백그라운드 컨텍스트의 큐에는 런루프가 없다. 다음처럼 그룹을 직접 관리한다.
  - `undoManager.groupsByEvent = false`로 둔다. true로 두고 Undo를 쓰면 그룹이 없어 크래시한다.
  - 변경마다 `beginUndoGrouping()`, `setActionName(_:)`, 변경, `processPendingChanges()`, `endUndoGrouping()` 순서로 호출한다.
  - Core Data는 `processPendingChanges` 시점에 Undo를 등록하므로, 그룹을 닫기 전에 반드시 호출한다.
- `undo()`, `redo()`는 컨텍스트 큐에서 호출한다.
- viewContext에서 Undo한 결과를 스토어에 남기려면 Undo 뒤에 저장한다.
- 시드 데이터처럼 사용자가 되돌리면 안 되는 변경은 `removeAllActions()`로 기록을 지운다.

### 코드

```swift
// UndoManager 알림으로 canUndo, canRedo를 다시 읽는다. UI는 이 값을 구독한다.
final class UndoState {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var undoActionName = ""
    @Published private(set) var redoActionName = ""

    private let undoManager: UndoManager
    private var tokens: [NSObjectProtocol] = []

    init(undoManager: UndoManager) {
        self.undoManager = undoManager
        let names: [Notification.Name] = [
            .NSUndoManagerDidCloseUndoGroup,    // Undo 그룹이 확정된 뒤
            .NSUndoManagerDidUndoChange,        // Undo 실행 뒤
            .NSUndoManagerDidRedoChange,        // Redo 실행 뒤
        ]
        tokens = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: undoManager,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        refresh()
    }

    private func refresh() {
        canUndo = undoManager.canUndo
        canRedo = undoManager.canRedo
        undoActionName = undoManager.undoActionName
        redoActionName = undoManager.redoActionName
    }

    deinit {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
}

// 백그라운드 컨텍스트에서 Undo 그룹을 직접 관리한다.
func undoGroup(name: String, task: @escaping () -> Void) {
    context.perform { [weak self] in
        guard let self else { return }
        context.undoManager?.beginUndoGrouping()
        context.undoManager?.setActionName(name)
        task()
        // Core Data는 processPendingChanges 시점에 undo를 등록하므로 그룹을 닫기 전에 호출해야 한다.
        context.processPendingChanges()
        context.undoManager?.endUndoGrouping()
    }
}

@objc func redoButtonTapped() {
    guard let um = context.undoManager, um.canRedo else { return }
    // undo, redo는 스레드 안전하지 않으므로 컨텍스트 큐에서 실행한다.
    context.perform { um.redo() }
}

// SwiftUI 목록: viewContext의 Undo 결과를 스토어에 남기려면 Undo 뒤에 저장한다.
func undo() {
    guard let undoManager = context.undoManager, undoManager.canUndo else { return }
    undoManager.undo()
    context.saveOrNotify("Undo 저장")
}
```

## 배치 요청

- `NSBatchInsertRequest`, `NSBatchUpdateRequest`, `NSBatchDeleteRequest`는 컨텍스트를 거치지 않고 스토어를 직접 바꾼다. 저장 알림이 없으므로 `automaticallyMergesChangesFromParent`도 동작하지 않는다.
- 반드시 아래 둘 중 하나로 SOT 플로우에 합류시킨다.

| 방법 | 쓸 때 | 방법 |
| --- | --- | --- |
| objectID 병합 | 변경 건수가 결과 건수에 비해 작을 때 | `resultType`을 objectID로 받아 `NSManagedObjectContext.mergeChanges(fromRemoteContextSave:into:)` |
| 다시 fetch | 전체 삽입, 전체 삭제처럼 변경이 결과의 상당 부분일 때 | `viewContext.reset()` 후 `performFetch()`, UI는 reloadData 경로 |

- 병합 비용은 변경 건수에 비례한다. 항목마다 KVO 알림, FRC 배열 갱신, diff 계산이 메인 스레드에서 일어난다. 다시 fetch하는 비용은 결과 건수에 비례한다.
- 다시 fetch할 때는 결과를 병합하지 않으므로 `resultType = .count`로 받는다. objectID 배열을 만들 필요가 없다.
- `viewContext.reset()`은 저장하지 않은 변경도 지운다. 읽기 전용으로 쓰는 viewContext에서만 쓴다.
- 병합 키: 삭제는 `NSDeletedObjectsKey`, 갱신은 `NSUpdatedObjectsKey`를 쓴다.
- dictionary 기반 batch insert(`dictionaryHandler`)는 관리 객체를 만들지 않아 빠르다. 키는 속성 이름과 같아야 하고 타입 검증이 없다.

### 코드: 다시 fetch해서 합류 (UIKit, 수만 건)

```swift
// 배치 요청은 컨텍스트를 거치지 않으므로 viewContext는 변경을 모른다.
// 수만 건을 병합하면 항목마다 KVO 알림, FRC 배열 갱신, diff 계산이 메인 스레드에서 실행되어 화면이 멈춘다.
// 병합 비용은 변경 건수에, 다시 fetch하는 비용은 결과 건수에 비례하므로 전체 삽입이나 삭제에는 다시 fetch가 유리하다.
private func refreshController() {
    // 배치 요청 이전에 등록된 객체는 스토어와 어긋난 상태이므로 컨텍스트를 비운다.
    // 저장되지 않은 변경도 함께 사라지므로 읽기 전용 viewContext에서만 쓴다.
    container.viewContext.reset()
    // FRC delegate가 이 플래그를 보고 diff 대신 reloadData 경로를 고른다. (uikit.md의 ③)
    isRefetching = true
    defer { isRefetching = false }
    do {
        try fetchedResultsController.performFetch()
    } catch {
        showError("다시 fetch 실패\n\(error.localizedDescription)")
    }
}

func createRecords(count itemCount: Int) {
    let context = container.newBackgroundContext()
    context.perform { [weak self] in
        var index = 0
        // dictionaryHandler는 NSManagedObject를 만들지 않고 스토어에 바로 쓰므로 managedObjectHandler보다 빠르다.
        // 키는 속성 이름과 같아야 하며, 타입 검증이 없으므로 모델과 어긋나면 실행 시점에 실패한다.
        // 관리 객체를 만들지 않으므로 awakeFromInsert도 호출되지 않는다. recordId와 시각을 직접 넣는다.
        let now = Date.now
        let request = NSBatchInsertRequest(entity: Record.entity()) { (dictionary: NSMutableDictionary) in
            guard index < itemCount else { return true }
            dictionary.setValue(UUID().uuidString, forKeyPath: #keyPath(Record.recordId))
            dictionary.setValue("Record_\(index)", forKeyPath: #keyPath(Record.title))
            dictionary.setValue(RecordCategory.inbox.rawValue, forKeyPath: #keyPath(Record.category))
            dictionary.setValue(Int32.random(in: 0...100_000), forKeyPath: #keyPath(Record.amount))
            dictionary.setValue(now, forKeyPath: #keyPath(Record.createdAt))
            dictionary.setValue(now, forKeyPath: #keyPath(Record.updatedAt))
            index += 1
            return false
        }
        // 결과를 병합하지 않고 다시 fetch로 반영하므로 objectID 배열을 만들 필요가 없다.
        request.resultType = .count

        do {
            _ = try context.execute(request)
            Task { @MainActor [weak self] in
                self?.refreshController()
            }
        } catch {
            showError("아이템 생성 실패\n\(error.localizedDescription)")
        }
    }
}

// isMerge가 true면 objectID 병합, false면 다시 fetch로 합류한다.
func removeRecords(predicate: NSPredicate? = nil, isMerge: Bool = false) {
    let context = container.newBackgroundContext()
    context.perform { [weak self] in
        guard let self else { return }
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Record.fetchRequest()
        fetchRequest.predicate = predicate

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let ids = result?.result as? [NSManagedObjectID] ?? []
            if isMerge {
                // 변경 건수가 많으면 FRC와 diffable data source의 diff 비용이 커진다.
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                    into: [container.viewContext]
                )
            } else {
                Task { @MainActor [weak self] in
                    self?.refreshController()
                }
            }
        } catch {
            showError("아이템 제거 실패\n\(error.localizedDescription)")
        }
    }
}
```

### 코드: objectID 병합으로 합류 (SwiftUI)

아래 함수는 `@Environment(\.managedObjectContext) private var context`로 viewContext를 주입받은 뷰 안에 있다.
백그라운드 컨텍스트는 stack.md의 `makeBackgroundContext()`로 만든다.
ViewModel이 컨테이너를 주입받은 구조라면 `context.makeBackgroundContext()` 대신 `container.newBackgroundContext()`를, 병합 대상으로 `container.viewContext`를 쓴다.

```swift
// NSBatchUpdateRequest는 스토어에 직접 SQL을 실행하므로 어떤 컨텍스트도 변경을 모른다.
// 결과 objectID를 병합해야 viewContext의 객체가 갱신되고 objectWillChange가 발행된다.
func raiseAmountsByBatch() {
    let viewContext = context
    let background = viewContext.makeBackgroundContext()
    background.perform {
        let request = NSBatchUpdateRequest(entity: Record.entity())
        request.propertiesToUpdate = [
            #keyPath(Record.amount): NSExpression(format: "%K * 1.1", #keyPath(Record.amount)),
        ]
        request.resultType = .updatedObjectIDsResultType
        do {
            let result = try background.execute(request) as? NSBatchUpdateResult
            let ids = result?.result as? [NSManagedObjectID] ?? []
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSUpdatedObjectsKey: ids],
                into: [viewContext]
            )
        } catch {
            showError("[배치 업데이트 실패] \(error.localizedDescription)")
        }
    }
}

// 병합되면 FRC가 삭제를 감지하고, 행 뷰는 Record.isUsable 확인으로 폴트 접근을 피한다.
func deleteAllByBatch() {
    let viewContext = context
    let background = viewContext.makeBackgroundContext()
    background.perform {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Record.fetchRequest()
        let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        request.resultType = .resultTypeObjectIDs
        do {
            let result = try background.execute(request) as? NSBatchDeleteResult
            let ids = result?.result as? [NSManagedObjectID] ?? []
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: ids],
                into: [viewContext]
            )
        } catch {
            showError("[배치 삭제 실패] \(error.localizedDescription)")
        }
    }
}

// 배치가 아닌 일반 백그라운드 저장은 automaticallyMergesChangesFromParent로 자동 병합된다.
// 병합 과정에서 각 Record의 objectWillChange가 발행되어 행 뷰가 갱신된다.
func activateAllOnBackground() {
    // 같은 코디네이터에서 저장하므로 별도 병합 코드가 필요 없다.
    let background = context.makeBackgroundContext()
    background.perform {
        do {
            let request = Record.fetchRequest()
            request.predicate = NSPredicate(format: "%K == NO", #keyPath(Record.isActive))
            let targets = try background.fetch(request)
            targets.forEach { $0.isActive = true }
            try background.save()
        } catch {
            background.rollback()
            showError("[백그라운드 저장 실패] \(error.localizedDescription)")
        }
    }
}
```

## 외부 데이터 동기화

```
원격 값 조회 → 로컬 인덱스 조회 → 계획(삽입, 갱신, 삭제) → 배치 삭제 → 배치 upsert → objectID 병합 → FRC
```

1. **로컬 인덱스:** 비교에 필요한 키와 수정 시각만 `dictionaryResultType`, `propertiesToFetch`로 가져온다. dictionary 결과는 스토어를 직접 읽으므로 `includesPendingChanges = false`로 둔다.
2. **계획:** 모든 로컬 키를 삭제 후보로 두고, 원격에 있는 키는 후보에서 뺀다. 원격에만 있으면 삽입, 원격의 수정 시각이 더 늦으면 갱신한다.
3. **삭제:** `NSBatchDeleteRequest`에 `"id in %@"` predicate를 쓰고 결과는 objectID로 받는다.
4. **upsert:** 삽입과 갱신을 한 번의 `NSBatchInsertRequest`로 처리한다.
   - 엔티티에 유니크 제약이 있어야 한다.
   - 실행하는 컨텍스트의 merge policy가 `mergeByPropertyObjectTrump`여야 기존 행을 덮어쓴다.
5. **병합:** 삭제 결과는 `NSDeletedObjectsKey`, upsert 결과는 `NSUpdatedObjectsKey`로 viewContext에 병합한다. 신규 행이 섞여 있어도 FRC는 updated로 통지된 객체가 결과에 포함되는지 다시 평가하므로 화면에 반영된다.

- 동기화 코드는 화면을 모른다. 결과는 병합으로만 전달된다.
- 원격 모델과 엔티티 사이 변환은 `map(model:)` 하나로 한다.

### 코드

`RecordModel`과 `map(model:)`은 stack.md의 "엔티티와 렌더링 모델 경계"에 있다.
여기서 `RecordModel`은 원격 데이터를 담는 값 모델이고, 엔티티에 기록된 뒤에는 버린다. 값이 남는 곳은 엔티티 하나다.
`Record.recordId`에는 모델 편집기에서 유니크 제약을 건다.

```swift
// 원격 데이터를 값 타입으로 돌려주는 경계다. 네트워크 계층이 구현한다.
protocol RecordRemoteClient {
    func fetchRecords() async throws -> [RecordModel]
}

final class RecordSyncer {
    private let remote: RecordRemoteClient
    // 화면은 이 컨테이너의 viewContext에 FRC를 붙이고, 동기화가 필요할 때 sync()만 호출한다.
    let container: NSPersistentContainer

    init(remote: RecordRemoteClient, container: NSPersistentContainer) {
        self.remote = remote
        self.container = container
    }

    struct SyncPlan {
        var toInsert: [RecordModel] = []
        var toUpdate: [RecordModel] = []
        var toDelete: Set<String> = []
    }

    func sync() async throws {
        let syncPlan = makeSyncPlan(
            local: try fetchLocalIndex(container.newBackgroundContext()),
            remote: try await remote.fetchRecords()
        )
        let (deleted, upserted) = try process(syncPlan: syncPlan)

        // 배치 요청 결과는 viewContext가 모르므로 objectID를 직접 병합한다.
        // 삭제는 반드시 NSDeletedObjectsKey로 병합한다. NSUpdatedObjectsKey로 병합하면
        // 이미 지워진 행에 refresh가 걸려 폴트를 채우지 못한다.
        // upsert 결과는 신규 행과 갱신 행이 섞여 있어 NSUpdatedObjectsKey로 병합한다.
        // FRC는 updated로 통지된 객체가 결과에 포함되는지 다시 평가하므로 신규 행도 화면에 나타난다.
        var changes: [AnyHashable: Any] = [:]
        if !deleted.isEmpty { changes[NSDeletedObjectsKey] = deleted }
        if !upserted.isEmpty { changes[NSUpdatedObjectsKey] = upserted }
        if !changes.isEmpty {
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: changes,
                into: [container.viewContext]
            )
        }
    }

    private func process(syncPlan: SyncPlan) throws -> (deleted: [NSManagedObjectID], upserted: [NSManagedObjectID]) {
        let context = container.newBackgroundContext()
        // batch insert에서 유니크 제약이 충돌하면 삽입하려는 값이 스토어 값을 덮어쓴다.
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        return try context.performAndWait {
            var deleted: [NSManagedObjectID] = []
            var upserted: [NSManagedObjectID] = []

            // 1. 삭제
            if !syncPlan.toDelete.isEmpty {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Record")
                fetchRequest.predicate = NSPredicate(format: "recordId in %@", syncPlan.toDelete)
                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                batchDeleteRequest.resultType = .resultTypeObjectIDs

                let deleteResult = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                if let objectIDs = deleteResult?.result as? [NSManagedObjectID] {
                    deleted.append(contentsOf: objectIDs)
                }
            }

            // 2. 삽입과 갱신을 한 번의 batch insert로 처리한다. recordId 유니크 제약 덕분에 upsert가 된다.
            let objects = syncPlan.toInsert + syncPlan.toUpdate
            if !objects.isEmpty {
                var insertIndex = 0
                // entity 객체 대신 이름으로 요청을 만들어 실행하는 컨텍스트의 모델에서 entity를 찾게 한다.
                // 같은 momd가 여러 모델 인스턴스로 로드된 상태에서 Record.entity()는
                // 다른 모델 소속의 entity를 돌려줄 수 있고, 그러면 batch insert가 예외로 종료된다.
                let insertRequest = NSBatchInsertRequest(entityName: "Record", managedObjectHandler: { object in
                    // false는 "현재 객체를 넣고 다음으로", true는 "삽입 종료"다.
                    guard
                        insertIndex < objects.count,
                        let record = object as? Record
                    else { return true }
                    record.map(model: objects[insertIndex])
                    insertIndex += 1
                    return false
                })
                insertRequest.resultType = .objectIDs

                let insertResult = try context.execute(insertRequest) as? NSBatchInsertResult
                if let objectIDs = insertResult?.result as? [NSManagedObjectID] {
                    upserted.append(contentsOf: objectIDs)
                }
            }
            return (deleted, upserted)
        }
    }

    private func makeSyncPlan(local: [String: Date], remote: [RecordModel]) -> SyncPlan {
        var plan = SyncPlan()
        // 모든 로컬 키를 삭제 후보로 올리고, 원격에 있는 키는 뺀다.
        plan.toDelete = Set(local.keys)

        for remoteItem in remote {
            guard let localUpdatedAt = local[remoteItem.id] else {
                // 로컬에 없으면 삽입한다.
                plan.toInsert.append(remoteItem)
                continue
            }
            plan.toDelete.remove(remoteItem.id)
            // 원격에서 더 늦게 수정되었으면 갱신한다.
            if remoteItem.updatedAt > localUpdatedAt {
                plan.toUpdate.append(remoteItem)
            }
        }
        return plan
    }

    // 비교에 필요한 recordId와 updatedAt만 dictionary로 가져와 엔티티 전체를 로드하는 비용을 줄인다.
    private func fetchLocalIndex(_ context: NSManagedObjectContext) throws -> [String: Date] {
        let request = NSFetchRequest<NSDictionary>(entityName: "Record")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["recordId", "updatedAt"]
        // dictionaryResultType은 스토어 값을 직접 읽으므로 저장 전 변경은 포함할 수 없다.
        request.includesPendingChanges = false

        return try context.performAndWait {
            try context.fetch(request).reduce(into: [:]) { acc, row in
                guard let id = row["recordId"] as? String,
                      let updated = row["updatedAt"] as? Date else { return }
                acc[id] = updated
            }
        }
    }
}
```

## refresh

| | `refresh(_:mergeChanges: false)` | `refresh(_:mergeChanges: true)` |
| --- | --- | --- |
| 저장되지 않은 변경 | 버림 | 다시 로드한 값 위에 다시 적용 |
| 객체 상태 | 폴트로 전환 (`didTurnIntoFault` 호출) | 영구 속성을 다시 로드 |
| Transient 속성 | `nil`로 초기화 | 유지 |
| 쓸 때 | 변경 폐기, Transient 캐시 초기화, 메모리 해제 | 외부 변경을 받으면서 편집 중인 값은 지킬 때 |

- refresh도 KVO 알림을 발생시키므로 관찰 중인 UI는 같은 플로우로 갱신된다.
- Transient 속성은 계산 결과 캐시로 쓸 수 있다. 저장되지 않으므로 앱을 다시 실행하거나 `mergeChanges: false`로 refresh하면 다시 계산한다.

### 코드

```swift
// cachedSummary는 Transient 속성이다. 스토어에 저장되지 않는다.
// Codegen: Category/Extension. awakeFromInsert는 stack.md의 "모델 정의와 Codegen" 코드와 같다.
@objc(Record)
class Record: NSManagedObject {
    override func awakeFromInsert() { ... }

    override func didTurnIntoFault() {
        super.didTurnIntoFault()
        // mergeChanges: false로 refresh하면 여기가 호출되고 cachedSummary는 nil이 된다.
        print("[\(Self.self)] 폴트 상태가 되었습니다. cachedSummary: \(cachedSummary ?? "nil")")
    }
}

extension Record {
    // 계산 비용이 큰 요약 문자열을 Transient 속성에 캐시한다.
    @MainActor
    func summary() async -> String {
        if let cachedSummary {
            return cachedSummary
        }
        try? await Task.sleep(for: .seconds(3))   // 무거운 계산 자리
        let summary = "\(displayTitle) · \(displayAmount)"
        cachedSummary = summary
        return summary
    }
}

@objc func resetButtonTapped() {
    guard let record else { return }
    // mergeChanges: false
    //   저장되지 않은 변경을 버리고 객체를 폴트로 되돌린다. 이때 didTurnIntoFault가 호출된다.
    //   Transient 속성은 nil이 되고, 다음 summary() 호출에서 다시 계산한다.
    //   KVO 알림도 발생하므로 cachedSummary를 구독하는 라벨이 갱신된다.
    //   영구 속성(title, amount 등)은 다음에 접근할 때 row cache나 스토어에서 다시 로드된다.
    // mergeChanges: true
    //   영구 속성을 다시 로드한 뒤 저장되지 않은 변경을 그 위에 다시 적용한다.
    //   Transient 속성 값도 유지되므로 캐시 초기화 용도에는 맞지 않는다.
    container.viewContext.refresh(record, mergeChanges: false)
}
```
