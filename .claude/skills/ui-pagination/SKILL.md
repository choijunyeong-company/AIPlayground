---
name: ui-pagination
description: iOS 목록 화면에 페이징(무한 스크롤, pull-to-refresh)을 구현할 때 사용한다. SwiftUI와 UIKit 각각에서 어떤 이벤트로 다음 페이지를 요청하는지, View와 ViewModel이 어떻게 소통하는지, 공용 Paginator로 두 프레임워크의 페이징 동작을 단일 코드로 관리하는 방법을 다룬다.
---

# ui-pagination

페이징 로직은 `Paginator` 하나에만 둔다.
ViewModel은 View 이벤트를 Paginator 호출로 옮기고 오류를 사용자 메시지로 바꾼다.
View는 스크롤 이벤트를 전달하고 Paginator 상태를 그린다.

```
View (SwiftUI / UIKit)  ── 이벤트 ──▶  ViewModel  ── refresh() / fetchNext() ──▶  Paginator<Item, Page>
       ▲                                  │                                         │
       └──── items, isLoading, hasNext ◀──┼──── @Observable 또는 @Published ───────┘
       └──── errorMessage ◀───────────────┘
```

이 문서의 예시 타입(`Article`, `ArticlePage`, `ArticleAPI`)은 설명용 이름이다.
실제 프로젝트의 모델과 API 타입으로 바꿔 쓴다.

## 작업 순서

1. 대상 프로젝트의 최소 지원 버전(`IPHONEOS_DEPLOYMENT_TARGET`)과 목록 화면에 쓰는 UI 프레임워크를 확인하고 상태 노출 방식을 고른다. ([상태 노출 방식](#상태-노출-방식))
2. 프로젝트에 `Paginator` 타입이 있는지 검색한다. 없으면 고른 방식에 맞는 reference 파일을 프로젝트에 복사한다.
3. 화면별 `Page` 커서와 Paginator 팩토리를 만든다. ([1. Page와 팩토리](#1-page와-팩토리))
4. ViewModel을 만든다. ([2. ViewModel](#2-viewmodel))
5. 프레임워크에 맞춰 View를 연결한다. ([3. SwiftUI](#3-swiftui), [4. UIKit](#4-uikit))
6. [점검 목록](#점검-목록)을 확인한다.

## 상태 노출 방식

`Paginator`가 상태를 노출하는 방식은 프로젝트 조건으로 정한다.

| 조건 | 노출 방식 | 복사할 파일 | View의 구독 방식 |
| --- | --- | --- | --- |
| SwiftUI에서만 사용 | Observation (`@Observable`) | [reference/ObservablePaginator.swift](reference/ObservablePaginator.swift) | `body`에서 읽기만 하면 자동 추적 |
| UIKit에서도 사용, 최소 지원 iOS 26 이상 | Observation (`@Observable`) | [reference/ObservablePaginator.swift](reference/ObservablePaginator.swift) | `updateProperties()`에서 읽기만 하면 자동 추적 |
| UIKit에서도 사용, 최소 지원 iOS 26 미만 | Combine (`ObservableObject`, `@Published`) | [reference/CombinePaginator.swift](reference/CombinePaginator.swift) | SwiftUI는 `@ObservedObject`, UIKit은 `$items.sink` |

- 두 파일 모두 타입 이름이 `Paginator`이고 `PaginatorError`를 포함한다. 한 프로젝트에는 하나만 복사한다.
- 복사할 때 파일 이름은 `Paginator.swift`로 바꾼다.
- 한 프로젝트 안에서는 한 가지 방식만 쓴다. Observation을 쓰면 ViewModel도 `@Observable`로 맞추고 Combine 구독 코드를 두지 않는다.
- SwiftUI만 쓰는 Observation 방식은 최소 지원 iOS 17 이상이 필요하다.

## Paginator가 보장하는 것

이 동작은 ViewModel과 View에서 다시 구현하지 않는다.

| 동작 | 보장 방식 |
| --- | --- |
| 중복 요청 차단 | 요청 중에 `fetchNext()`를 다시 호출하면 `.isLoading`을 던진다. |
| 마지막 페이지 판단 | `fetch`가 `nextPage: nil`을 반환하면 `hasNext`가 `false`가 되고, 이후 호출은 `.noMorePages`를 던진다. |
| refresh 우선 | `refresh()`는 진행 중인 `fetchNext()`를 취소하고 끝날 때까지 기다린 뒤 첫 페이지를 다시 받는다. 취소된 응답은 `items`에 반영되지 않는다. |
| 결과 반영 | `refresh()`는 `items`를 교체하고, `fetchNext()`는 `items` 뒤에 붙인다. |
| 상태 공개 | `items`, `hasNext`, `isLoading`을 읽기 전용으로 공개한다. |

공개 API는 아래와 같다.

| API | 설명 |
| --- | --- |
| `init(initialPage:fetch:)` | 첫 페이지 커서와 `(Page) async throws -> (items: [Item], nextPage: Page?)` 클로저를 받는다. |
| `refresh()` | 첫 페이지부터 다시 받는다. `async throws(PaginatorError)` |
| `fetchNext()` | 다음 페이지를 받아 뒤에 붙인다. `async throws(PaginatorError)` |
| `initiate()` | 첫 로드용 이름이며 `refresh()`와 같다. |
| `fetchTaskPriority` | 요청 Task의 우선순위. 기본값은 `.userInitiated`이다. |

`PaginatorError`의 케이스는 `taskIsCancelled`, `isLoading`, `noMorePages`, `fetchFailure(underlyingError:)`, `unknown(error:)`이다.

## 1. Page와 팩토리

페이지 커서는 API가 요구하는 값만 담는 `Sendable` 값 타입으로 만든다.

offset 방식:

```swift
struct ArticlePage: Hashable, Sendable {
    let limit: Int
    let offset: Int

    static let first = ArticlePage(limit: 20, offset: 0)

    func next() -> ArticlePage {
        ArticlePage(limit: limit, offset: offset + limit)
    }
}
```

cursor 방식에서는 서버가 준 cursor를 그대로 커서로 쓴다.
첫 페이지는 `nil` cursor로 표현한다.

```swift
struct ArticleCursor: Hashable, Sendable {
    let value: String?
    static let first = ArticleCursor(value: nil)
}
```

API 호출을 Paginator로 감싸는 팩토리는 `Paginator` extension에 둔다.
SwiftUI와 UIKit ViewModel이 같은 팩토리를 쓰므로 페이징 규칙이 한 곳에만 존재한다.

```swift
typealias ArticlePaginator = Paginator<Article, ArticlePage>

extension Paginator where Item == Article, Page == ArticlePage {
    static func articles(api: any ArticleAPI) -> ArticlePaginator {
        ArticlePaginator(initialPage: .first) { page in
            let response = try await api.fetchArticles(limit: page.limit, offset: page.offset)
            // 다음 페이지가 없으면 nil을 반환해야 hasNext가 false가 된다.
            let nextPage = response.hasMore ? page.next() : nil
            return (response.items, nextPage)
        }
    }
}
```

- `Item`과 `Page`는 `Sendable`이어야 한다.
- 마지막 페이지 판단 기준은 API마다 다르다. `next` URL 유무, `hasMore` 플래그, 받은 개수가 `limit`보다 작은지 등을 API 명세에서 확인한다.

## 2. ViewModel

ViewModel의 역할은 세 가지로 제한한다.

1. View 이벤트 이름 그대로 메서드를 노출한다. 예: `viewDidLoad()`, `lastCellWillDisplay()`, `refreshTriggered()`, `retry()`
2. 이벤트를 `paginator.refresh()` 또는 `paginator.fetchNext()` 호출로 옮긴다.
3. `PaginatorError`를 사용자 메시지(`errorMessage`)로 바꾼다.

목록 상태(`items`, `isLoading`, `hasNext`)를 ViewModel에 복사하지 않는다.
`paginator`를 그대로 공개하고 View가 직접 구독한다.
`errorMessage`는 Observation 방식이면 `@Observable` ViewModel의 일반 프로퍼티로, Combine 방식이면 `@Published`로 둔다.

### 오류 메시지 변환

취소, 중복 요청, 마지막 페이지는 정상 흐름이므로 사용자에게 알리지 않는다.
이 판단은 `PaginatorError` extension 하나에 두고 모든 ViewModel이 함께 쓴다.

```swift
extension PaginatorError {
    /// 사용자에게 보여줄 메시지. 알릴 필요가 없는 경우는 nil이다.
    var userMessage: String? {
        switch self {
        case .taskIsCancelled, .isLoading, .noMorePages:
            return nil
        case .fetchFailure(let underlying):
            // URLSession이 Task 취소를 URLError(.cancelled)로 던지는 경우도 거른다.
            if underlying is CancellationError { return nil }
            if (underlying as? URLError)?.code == .cancelled { return nil }
            return underlying.localizedDescription
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
```

프로젝트에 자체 네트워크 오류 타입이 있으면 그 타입의 취소 케이스도 같은 위치에서 `nil`로 거른다.

ViewModel에는 오류 처리를 모은 `perform` 헬퍼를 둔다.

```swift
private func perform(_ operation: () async throws -> Void) async {
    do {
        try await operation()
    } catch let error as PaginatorError {
        if let message = error.userMessage { errorMessage = message }
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### 이벤트와 Paginator 호출

| View 이벤트 | ViewModel 메서드 | Paginator 호출 | 비고 |
| --- | --- | --- | --- |
| 화면 첫 표시 | `viewDidLoad()` / `onAppear()` | `refresh()` | SwiftUI `onAppear`는 여러 번 호출되므로 플래그로 한 번만 실행한다. |
| 마지막 아이템 표시 | `lastCellWillDisplay()` / `lastItemAppeared()` | `fetchNext()` | `guard paginator.hasNext`로 불필요한 Task 생성을 막는다. |
| pull-to-refresh | `refreshTriggered()` / `refresh() async` | `refresh()` | SwiftUI는 `async`로 끝까지 기다린다. |
| 오류 알림의 다시 시도 | `retry()` | `refresh()` | `errorMessage = nil` 후 호출한다. |

## 3. SwiftUI

### 다음 페이지 요청 이벤트

마지막 행의 `.onAppear`에서 요청한다.

```swift
List(viewModel.paginator.items) { item in
    ArticleRow(item: item)
        .onAppear {
            guard item.id == viewModel.paginator.items.last?.id else { return }
            viewModel.lastItemAppeared()
        }
}
.refreshable { await viewModel.refresh() }
.onAppear { viewModel.onAppear() }
```

- `.refreshable` 클로저는 `async`로 ViewModel을 기다려야 한다. `Task { }`로 감싸 바로 반환하면 refresh 인디케이터가 즉시 사라진다.
- 로딩 표시는 `paginator.isLoading`을 그대로 쓴다.
- `List`에 넘기는 `Item`은 `Identifiable`이거나 `id:` 키 경로를 지정해야 한다.

### View와 ViewModel 소통

ViewModel은 `@Observable`로 만들고, View는 이벤트 메서드만 호출한다.

#### Paginator가 `@Observable`인 경우

View는 `viewModel.paginator.items`를 `body`에서 읽기만 한다.
SwiftUI가 읽은 프로퍼티를 자동으로 추적하므로 프로퍼티 래퍼가 필요 없다.

```swift
@MainActor
@Observable
final class ArticleListViewModel {
    var errorMessage: String?
    let paginator: ArticlePaginator
    @ObservationIgnored private var isAppeared = false

    init(api: any ArticleAPI) {
        paginator = .articles(api: api)
    }

    func onAppear() {
        guard !isAppeared else { return }
        isAppeared = true
        Task { await refresh() }
    }

    func refresh() async { await perform { try await paginator.refresh() } }

    func lastItemAppeared() {
        guard paginator.hasNext else { return }
        Task { await perform { try await paginator.fetchNext() } }
    }

    func retry() {
        errorMessage = nil
        Task { await refresh() }
    }
}

struct ArticleListView: View {
    let viewModel: ArticleListViewModel

    var body: some View {
        List(viewModel.paginator.items) { item in
            // 위의 다음 페이지 요청 예시와 같다.
        }
        .overlay { if viewModel.paginator.isLoading { ProgressView() } }
    }
}
```

#### Paginator가 `ObservableObject`인 경우

SwiftUI View가 `paginator`를 `@ObservedObject`로 직접 관찰해야 `items` 변경이 화면에 반영된다.
`@Observable` ViewModel 안에 `paginator`를 넣어 두기만 하면 Observation이 `@Published` 변경을 추적하지 않는다.

```swift
struct ArticleListView: View {
    let viewModel: ArticleListViewModel
    @ObservedObject private var paginator: ArticlePaginator

    init(viewModel: ArticleListViewModel) {
        self.viewModel = viewModel
        self.paginator = viewModel.paginator
    }
    // body에서는 paginator.items, paginator.isLoading을 읽는다.
}
```

이때 ViewModel의 `paginator`에는 `@ObservationIgnored`를 붙인다.

### 오류 알림

`errorMessage != nil`을 `Binding<Bool>`로 바꿔 `.alert`에 연결한다.

```swift
.alert("오류", isPresented: Binding(
    get: { viewModel.errorMessage != nil },
    set: { if !$0 { viewModel.errorMessage = nil } }
)) {
    Button("다시 시도") { viewModel.retry() }
    Button("확인", role: .cancel) {}
} message: {
    Text(viewModel.errorMessage ?? "")
}
```

## 4. UIKit

### 다음 페이지 요청 이벤트

`UICollectionViewDelegate.collectionView(_:willDisplay:forItemAt:)`에서 마지막 셀일 때 요청한다.
`UITableView`는 `tableView(_:willDisplay:forRowAt:)`를 같은 방식으로 쓴다.

```swift
func collectionView(
    _ collectionView: UICollectionView,
    willDisplay cell: UICollectionViewCell,
    forItemAt indexPath: IndexPath
) {
    let lastItem = collectionView.numberOfItems(inSection: indexPath.section) - 1
    guard indexPath.item == lastItem else { return }
    viewModel.lastCellWillDisplay()
}
```

- `scrollViewDidScroll`의 offset 계산보다 단순하고, 셀 높이가 바뀌어도 동작이 같다.
- 더 일찍 불러오려면 `lastItem - n`과 비교한다. 중복 호출은 Paginator가 막는다.
- pull-to-refresh는 `UIRefreshControl`의 `.valueChanged`를 `viewModel.refreshTriggered()`로 연결한다.
- 목록 갱신은 `UICollectionViewDiffableDataSource` 스냅샷 전체 적용으로 처리한다. 교체인지 추가인지는 diff가 판단하므로 View는 구분하지 않는다. 이때 `Item`은 `Hashable`이어야 한다.

```swift
func applySnapshot(_ items: [Article]) {
    var snapshot = NSDiffableDataSourceSnapshot<Int, Article>()
    snapshot.appendSections([0])
    snapshot.appendItems(items)
    dataSource.apply(snapshot, animatingDifferences: view.window != nil)
}
```

### View와 ViewModel 소통

#### 최소 지원 iOS 26 이상: Observation

iOS 26부터 UIKit은 `updateProperties()`, `viewWillLayoutSubviews()` 같은 갱신 메서드 안에서 읽은 `@Observable` 프로퍼티를 자동으로 추적한다.
추적한 값이 바뀌면 UIKit이 해당 메서드를 다시 호출하므로 구독 코드와 `cancellables`가 필요 없다.
ViewModel은 SwiftUI와 같은 `@Observable` 클래스를 쓴다.

```swift
final class ArticleListViewController: UIViewController {
    private let viewModel: ArticleListViewModel

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.viewDidLoad()
    }

    // 여기서 읽은 paginator.items, paginator.isLoading, errorMessage가 바뀌면 다시 호출된다.
    override func updateProperties() {
        super.updateProperties()
        applySnapshot(viewModel.paginator.items)

        let isLoading = viewModel.paginator.isLoading
        loadingView.isHidden = !isLoading
        if !isLoading { refreshControl.endRefreshing() }

        if let message = viewModel.errorMessage, presentedViewController == nil {
            presentErrorAlert(message)
        }
    }
}
```

- 상태 반영은 `updateProperties()` 한 곳에 모은다. `viewDidLoad()`나 이벤트 핸들러에서 읽은 값은 추적되지 않는다.
- `updateProperties()`는 추적한 값 중 하나만 바뀌어도 전체가 다시 실행된다. 그래서 `applySnapshot`이 `isLoading` 변경 때도 호출되지만, 같은 스냅샷을 적용하면 diff 결과가 비어 있어 화면은 바뀌지 않는다.
- 오류 알림을 닫을 때 `viewModel.errorMessage = nil`로 지워야 같은 메시지가 다시 표시되지 않는다.

#### 최소 지원 iOS 26 미만: Combine

ViewModel은 `@MainActor final class`로 만들고 `@Published var errorMessage`만 소유한다.
ViewController는 `bind(viewModel:)`에서 Combine으로 `paginator`와 `errorMessage`를 구독한다.

```swift
func bind(viewModel: ArticleListViewModel) {
    cancellables.removeAll()
    self.viewModel = viewModel

    viewModel.paginator.$items
        .sink { [weak self] in self?.applySnapshot($0) }
        .store(in: &cancellables)

    viewModel.paginator.$isLoading
        .sink { [weak self] isLoading in
            self?.loadingView.isHidden = !isLoading
            if !isLoading { self?.refreshControl.endRefreshing() }
        }
        .store(in: &cancellables)

    viewModel.$errorMessage
        .compactMap { $0 }
        .sink { [weak self] in self?.presentErrorAlert($0) }
        .store(in: &cancellables)
}
```

- `endRefreshing()`은 `isLoading`이 `false`가 될 때 호출한다. refresh가 실패해도 인디케이터가 남지 않는다.
- 첫 로드는 `viewDidLoad()`에서 `viewModel.viewDidLoad()`로 시작한다.

## 점검 목록

- 상태 노출 방식이 [상태 노출 방식](#상태-노출-방식) 표의 조건과 맞는가. 최소 지원 iOS 26 이상인데 Combine 구독 코드가 남아 있지 않은가.
- 팩토리의 `fetch`가 마지막 페이지에서 `nextPage: nil`을 반환하는가.
- ViewModel이 `items`, `isLoading`을 복사해 두지 않고 `paginator`를 그대로 공개하는가.
- `.isLoading`, `.noMorePages`, `.taskIsCancelled`, 네트워크 취소 오류가 사용자 알림으로 노출되지 않는가.
- `ObservableObject` 방식이면 SwiftUI View가 `paginator`를 `@ObservedObject`로 관찰하는가.
- UIKit Observation 방식이면 상태 반영이 `updateProperties()` 안에 있는가.
- SwiftUI `onAppear`의 첫 로드가 한 번만 실행되는가.
- `.refreshable`이 `async` 함수를 끝까지 기다리는가.
- UIKit에서 refresh 실패 후에도 `UIRefreshControl`이 멈추는가.
- 스크롤 중 refresh를 당겼을 때 이전 `fetchNext()` 결과가 새 목록 뒤에 붙지 않는가. Paginator를 수정했다면 이 동작을 다시 확인한다.
