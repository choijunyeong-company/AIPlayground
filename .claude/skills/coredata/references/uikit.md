# UIKit: FRC 기반 책임 명세

목록 화면은 아래 다섯 책임으로 나뉜다.
책임마다 입력, 출력, 소유하는 상태, 금지 사항을 정했으므로 이 단위로 다른 타입에 옮길 수 있다.
이 문서의 코드는 설명을 위해 뷰컨트롤러 하나가 다섯 책임을 모두 맡는다.

## 전체 흐름

```
[쓰기 주체] save / 병합
      ↓
viewContext 변경
      ↓
① 쿼리 정의 ─ FRC 생성 ─→ ② 변경 감지 (FRC delegate)
                              ↓ NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
                         ③ UI 업데이트 매핑 (reconfigure, 애니메이션 여부, reload 경로)
                              ↓ apply
                         ④ 항목 표시 (cell provider: objectID → 엔티티 → 속성 또는 매핑 모델 → 셀)
⑤ 화면: 레이아웃, 사용자 입력을 쓰기 주체에 전달, 라우팅
```

## ① 쿼리 정의

| 항목 | 내용 |
| --- | --- |
| 입력 | viewContext, 필터 조건, 정렬 조건 |
| 출력 | 설정된 `NSFetchedResultsController` |
| 소유 상태 | 없음 (FRC 생성만 담당) |

- FRC는 반드시 viewContext에 붙인다. UI는 메인 스레드에서 읽기 때문이다.
- `sectionNameKeyPath`를 쓰면 첫 번째 sort descriptor가 섹션 키와 같아야 한다. FRC는 결과를 순서대로 훑으며 섹션 키 값이 바뀌는 지점마다 섹션을 새로 만들기 때문이다.
- 결과가 많으면 `fetchBatchSize`를 지정한다. 접근하는 행만 row cache에 올라온다.
- 정렬 키에는 가능하면 모델 편집기에서 인덱스를 건다.
- `cacheName`은 쓰지 않는 한 `nil`로 둔다.

### 코드

```swift
// 섹션이 있는 목록
func makeFetchResultController() -> NSFetchedResultsController<Record> {
    let fetchRequest = Record.fetchRequest()
    fetchRequest.sortDescriptors = [
        // FRC는 결과를 순서대로 훑으며 sectionNameKeyPath 값이 바뀌는 지점마다 새 섹션을 만든다.
        // 첫 번째 sort descriptor가 섹션 키(category)와 같아야 같은 category가 하나의 섹션으로 묶인다.
        NSSortDescriptor(keyPath: \Record.category, ascending: true),
        NSSortDescriptor(keyPath: \Record.createdAt, ascending: true)
    ]
    let controller = NSFetchedResultsController(
        fetchRequest: fetchRequest,
        managedObjectContext: container.viewContext,
        sectionNameKeyPath: #keyPath(Record.category),
        cacheName: nil
    )
    controller.delegate = self
    return controller
}

// 수만 건 이상의 목록
func makeFetchResultController() -> NSFetchedResultsController<Record> {
    let fetchRequest = Record.fetchRequest()
    // 요소에 접근할 때 row cache에 한 번에 올릴 행의 수
    fetchRequest.fetchBatchSize = 20
    // Record.title은 모델 편집기에서 인덱스로 설정해 title 기준 정렬 fetch를 빠르게 한다.
    fetchRequest.sortDescriptors = [
        NSSortDescriptor(keyPath: \Record.title, ascending: true)
    ]
    let controller = NSFetchedResultsController(
        fetchRequest: fetchRequest,
        managedObjectContext: container.viewContext,
        sectionNameKeyPath: nil,
        cacheName: nil
    )
    controller.delegate = self
    return controller
}
```

## ② 변경 감지

| 항목 | 내용 |
| --- | --- |
| 입력 | FRC delegate 콜백 `controller(_:didChangeContentWith:)` |
| 출력 | `NSDiffableDataSourceSnapshot<String, NSManagedObjectID>` |
| 소유 상태 | FRC 인스턴스, 최초 fetch 수행 여부 |

- delegate는 스냅샷 콜백 하나만 구현한다. 이 콜백을 구현하면 행 단위 콜백(`didChange anObject` 등)은 쓰지 않는다.
- `performFetch()`를 호출해야 감지가 시작된다. 첫 fetch 결과도 같은 delegate 콜백으로 들어온다.
- 스냅샷의 섹션 식별자는 섹션 키 값이고, 아이템 식별자는 objectID다. objectID는 저장 전에는 임시 ID일 수 있다.
- 무거운 첫 fetch는 화면 전환 애니메이션이 끝난 뒤(`viewDidAppear`) 한 번만 수행한다.
- 이 책임을 다른 타입으로 옮길 때는 그 타입이 FRC와 delegate를 함께 소유하고, 변환된 스냅샷을 클로저나 publisher로 내보낸다. FRC를 뷰컨트롤러와 다른 타입이 나눠 갖지 않는다.

### 코드

```swift
// 가벼운 목록은 viewDidLoad에서 바로 fetch한다.
override func viewDidLoad() {
    super.viewDidLoad()
    setupCollectionView()
    do {
        try fetchedResultsController.performFetch()
    } catch {
        showError("[최초 fetch 실패] \(error.localizedDescription)")
    }
}

// 무거운 목록은 화면 전환 애니메이션이 끝난 뒤 한 번만 fetch한다.
private var hasPerformedInitialFetch = false

override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // 다른 화면에서 돌아올 때마다 다시 fetch하지 않도록 최초 1회만 실행한다.
    guard !hasPerformedInitialFetch else { return }
    hasPerformedInitialFetch = true
    // reset 후 performFetch를 실행한다. 코드는 writes.md의 "배치 요청"에 있다.
    refreshController()
}
```

## ③ UI 업데이트 매핑

| 항목 | 내용 |
| --- | --- |
| 입력 | ②의 스냅샷, 화면이 window에 붙어 있는지 여부, 전체 재fetch 중인지 여부 |
| 출력 | data source에 대한 `apply` 호출 |
| 소유 상태 | 재fetch 중 플래그(`isRefetching`) |

- **속성 변경 반영:** 아이템이 objectID이므로 속성만 바뀌면 diff에서 변화가 없다. FRC는 갱신된 객체의 ID를 스냅샷의 `reloadedItemIdentifiers`에 담아 준다. 이 값을 같은 스냅샷의 `reconfigureItems(_:)`에 넘긴 뒤 apply한다.
  - `reconfigureItems(_:)`는 `NSDiffableDataSourceSnapshot`의 메서드로, 스냅샷에 "내용을 다시 채울 아이템"이라는 표시만 남긴다. apply할 때 화면에 보이는 셀만 기존 셀 인스턴스로 cell provider가 다시 호출된다.
  - `reloadItems(_:)`와 달리 셀 교체와 `prepareForReuse`가 없다. 셀 타입을 바꿔야 할 때만 reload를 쓴다.
  - 매핑 모델을 쓰는 경우에도 이 경로가 매핑 모델을 다시 만드는 유일한 시점이다. cell provider가 다시 호출되면서 엔티티의 최신 값으로 매핑 모델이 새로 만들어진다.
- **애니메이션:** `animatingDifferences: view.window != nil`로 화면에 보일 때만 애니메이션을 적용한다.
- **전체 교체:** 결과를 통째로 다시 fetch한 경우에는 diff가 의미 없고 비용만 크다. `applySnapshotUsingReloadData`를 쓴다.
- 매핑 로직은 순수 함수로 분리할 수 있다. 입력은 스냅샷과 플래그, 출력은 적용할 스냅샷과 apply 방식이다.

### 코드

②와 ③은 같은 delegate 콜백 안에 있다.

```swift
// performFetch로 결과를 통째로 교체하는 중인지 여부다. delegate가 diff 대신 reloadData를 고르는 기준이다.
// 다시 fetch할 일이 없는 목록에서는 이 플래그와 분기를 빼도 된다.
private var isRefetching = false

extension RecordListViewController: NSFetchedResultsControllerDelegate {
    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
    ) {
        // 섹션은 sectionNameKeyPath 값, 아이템은 objectID다. objectID는 저장 전이면 임시 ID일 수 있다.
        var snap = snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>

        // 결과를 통째로 교체한 경우에는 이전 스냅샷과의 diff가 의미 없고,
        // 수만 건의 diff와 애니메이션이 메인 스레드를 점유하므로 reloadData 경로를 쓴다.
        if isRefetching {
            dataSource.applySnapshotUsingReloadData(snap)
            return
        }

        // FRC는 속성이 바뀐 객체의 ID만 reloadedItemIdentifiers에 담아 주므로 스냅샷 diff에는 변화가 없다.
        // 같은 스냅샷의 reconfigureItems(_:)로 표시해 두면 apply할 때 보이는 셀만 기존 인스턴스로 cell provider가 다시 호출된다.
        let reloaded = snap.reloadedItemIdentifiers
        if !reloaded.isEmpty {
            snap.reconfigureItems(reloaded)
        }

        // 화면이 뷰 계층에 붙어 있을 때만 애니메이션을 적용한다.
        dataSource.apply(snap, animatingDifferences: view.window != nil)
    }
}
```

## ④ 항목 표시

| 항목 | 내용 |
| --- | --- |
| 입력 | objectID, viewContext |
| 출력 | 구성된 셀 |
| 소유 상태 | 없음 (매핑 모델도 보관하지 않는다) |

- cell provider는 objectID로 viewContext에서 엔티티를 얻는다. 셀에 값을 넘기는 방법은 둘 중 하나다.
  - **엔티티 속성을 직접 사용:** cell provider 안에서 엔티티 속성을 읽어 셀의 `configure`에 원시 값(문자열, 숫자)으로 넘긴다. 엔티티와 화면의 모양이 거의 같을 때 쓴다.
  - **매핑 모델 사용:** 엔티티를 `toModel()`로 값 타입 매핑 모델로 바꿔 넘긴다. 원시값 해석, 관계 펼치기, 공용 셀 컴포넌트 입력처럼 차이가 클 때 쓴다. 판단 기준은 stack.md의 "엔티티와 렌더링 모델 경계"를 본다.
- 어느 방법이든 cell provider 안에서 엔티티를 읽는다. cell provider는 메인 스레드에서 viewContext로 호출되므로 이 안에서 엔티티 속성을 읽는 것은 안전하다.
- 셀은 `NSManagedObject`를 프로퍼티로 보관하지 않는다. 셀은 재사용되므로 다른 행의 객체를 잡고 있거나, 삭제된 객체를 나중에 읽어 크래시할 수 있다.
- 매핑 모델은 셀 구성 순간에만 만들고 버린다. 뷰컨트롤러나 ViewModel에 매핑 모델 배열을 따로 두지 않는다. 그러면 FRC 결과, 매핑 모델 배열, 스냅샷이 서로 어긋날 수 있다.
- `toModel()`은 필수 값이 비어 있으면 `nil`을 돌려준다. cell provider는 이 경우 빈 셀을 돌려주고 크래시하지 않는다.
- 객체가 이미 지워졌을 수 있는 경로에서는 `object(with:)` 대신 `existingObject(with:)`를 쓴다. 자세한 내용은 stack.md의 "삭제된 객체 접근 방지"를 본다.
- 셀 높이를 내용에 맞출 때는 `preferredLayoutAttributesFitting(_:)`에서 높이를 계산하는 self-sizing 셀을 쓴다. 모든 셀 높이가 같으면 한 번 측정해 `itemSize`로 고정한다.

### 코드

```swift
// 방법 1: 엔티티 속성을 직접 사용한다. 화면 모양이 엔티티와 거의 같을 때 쓴다.
func makeDataSource() -> UICollectionViewDiffableDataSource<String, NSManagedObjectID> {
    UICollectionViewDiffableDataSource<String, NSManagedObjectID>(
        collectionView: collectionView
    ) { [weak container] collectionView, indexPath, objectId in
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: RecordCell.id, for: indexPath
            ) as? RecordCell,
            // FRC가 방금 돌려준 ID를 같은 viewContext에서 쓰므로 object(with:)로 충분하다.
            // 배치 삭제가 일어나는 목록이면 existingObject(with:)를 쓴다.
            let record = container?.viewContext.object(with: objectId) as? Record
        else { return UICollectionViewCell() }
        // 셀에는 원시 값만 넘긴다. 셀이 Record를 보관하지 않게 한다.
        cell.configure(title: record.displayTitle, amount: record.displayAmount, isActive: record.isActive)
        return cell
    }
}

final class RecordCell: UICollectionViewCell {
    static let id = "RecordCell"

    // 방법 1: 원시 값을 받는다.
    func configure(title: String, amount: String, isActive: Bool) {
        titleLabel.text = title
        amountLabel.text = amount
        activeBadge.isHidden = !isActive
    }

    // 방법 2: 매핑 모델을 받는다.
    func configure(_ model: RecordModel) {
        titleLabel.text = model.title
        amountLabel.text = model.amount.formatted()
        categoryLabel.text = model.category.displayName
        activeBadge.isHidden = !model.isActive
    }
}

// 방법 2: 매핑 모델을 사용한다. category 원시값을 enum으로 해석해야 하므로 값 타입으로 바꾼다.
func makeDataSource() -> UICollectionViewDiffableDataSource<String, NSManagedObjectID> {
    UICollectionViewDiffableDataSource<String, NSManagedObjectID>(
        collectionView: collectionView
    ) { [weak container] collectionView, indexPath, objectId in
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: RecordCell.id, for: indexPath
            ) as? RecordCell,
            let entity = container?.viewContext.object(with: objectId) as? Record,
            // 매핑 모델은 여기서 만들고 셀에 넘긴 뒤 보관하지 않는다.
            // 속성이 바뀌면 reconfigureItems(_:)로 이 클로저가 다시 호출되어 새 매핑 모델이 만들어진다.
            let model = entity.toModel()
        else { return UICollectionViewCell() }
        cell.configure(model)
        return cell
    }
}

// 모든 셀 높이가 같으면 템플릿 셀로 한 번만 재서 itemSize로 고정한다.
private lazy var templateCell = RecordCell(frame: .zero)
private var cachedItemHeight: CGFloat?

func updateItemSize() {
    let width = collectionView.bounds.width
        - collectionView.contentInset.left - collectionView.contentInset.right
        - layout.sectionInset.left - layout.sectionInset.right
    guard width > 0 else { return }

    let height = cachedItemHeight ?? measuredItemHeight(forWidth: width)
    cachedItemHeight = height

    let newSize = CGSize(width: width, height: height)
    // itemSize를 대입하면 레이아웃이 무효화되어 이 메서드가 다시 호출된다. 같은 값이면 빠져나가야 무한 반복을 막는다.
    guard layout.itemSize != newSize else { return }
    layout.itemSize = newSize
}

func measuredItemHeight(forWidth width: CGFloat) -> CGFloat {
    // 실제 셀과 같은 구성으로 잰다. 한 줄로 표시되는 셀이라 문자열 길이는 높이에 영향이 없어 임의 값을 쓴다.
    templateCell.configure(title: "제목", amount: "0", isActive: true)
    let size = templateCell.contentView.systemLayoutSizeFitting(
        CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .fittingSizeLevel
    )
    return ceil(size.height)
}
```

## ⑤ 화면

- 레이아웃과 라우팅, 입력 전달만 맡는다.
- 행을 선택하면 data source에서 objectID를 꺼내 편집 화면에 넘긴다. 객체를 넘기지 않는다.
- 추가, 삭제 버튼은 쓰기 주체를 호출하고 끝낸다. 결과를 직접 목록에 넣지 않는다. 목록은 ②, ③ 경로로 갱신된다.

### 코드

```swift
// 컨테이너는 앱 진입점에서 만든 것을 생성자로 받는다. 뷰컨트롤러가 직접 만들지 않는다.
final class RecordListViewController: UIViewController {
    private let container: NSPersistentContainer
    private lazy var dataSource = makeDataSource()
    private lazy var fetchedResultsController = makeFetchResultController()

    init(container: NSPersistentContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }
}

extension RecordListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let objectId = dataSource.itemIdentifier(for: indexPath) else { return }
        presentEditor(objectId)
    }
}

// objectId가 nil이면 새 객체를 만드는 편집 화면이 된다. 편집 화면 코드는 writes.md의 "편집 경로"에 있다.
func presentEditor(_ objectId: NSManagedObjectID? = nil) {
    let editor = RecordEditViewController(container: container, objectId: objectId)
    let nav = UINavigationController(rootViewController: editor)
    nav.modalPresentationStyle = .pageSheet
    present(nav, animated: true)
}
```

## 책임 분리 예시

아키텍처에 따라 아래처럼 나눌 수 있다. 어느 경우든 SOT는 스토어 하나다.

| 아키텍처 | ①② 쿼리와 변경 감지 | ③ 매핑 | ④ 표시 | 쓰기 |
| --- | --- | --- | --- | --- |
| MVC | 뷰컨트롤러 | 뷰컨트롤러 | 뷰컨트롤러의 data source | 뷰컨트롤러, 편집 화면 |
| MVVM | ViewModel이 생성자로 컨테이너를 받아 FRC를 소유하고, 스냅샷을 publisher로 노출 | ViewModel 또는 뷰컨트롤러 | 뷰컨트롤러가 data source 소유, cell provider가 ViewModel에 `model(for: objectID)` 요청 | ViewModel이 쓰기 타입 호출 |
| Repository 계층 | Repository가 쿼리별 FRC를 만들어 스트림 제공 | 화면 계층 | 화면 계층 | Repository가 백그라운드 컨텍스트로 저장 |

분리할 때 지킬 것:

- data source(`UICollectionViewDiffableDataSource`)는 컬렉션뷰를 가진 쪽이 소유한다.
- 화면 계층 밖으로 나가는 값은 objectID, 원시 값, 매핑 모델이다. `NSManagedObject`를 ViewModel 프로퍼티로 오래 노출하지 않는다.
- `model(for: objectID)`는 호출될 때마다 viewContext에서 엔티티를 읽어 매핑 모델을 새로 만든다. ViewModel이 매핑 모델 배열을 캐시하지 않는다. 값이 있는 곳을 엔티티와 매핑 모델 두 곳으로 유지하기 위해서다.
- 쓰기 결과를 ViewModel이 별도 배열에 반영하지 않는다. 반영은 FRC가 한다.
