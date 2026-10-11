import Combine
import Foundation

public enum PaginatorError: Error {
    case taskIsCancelled
    case isLoading
    case noMorePages
    case fetchFailure(underlyingError: Error)
    case unknown(error: Error)
}

@MainActor
public final class Paginator<Item: Sendable, Page: Sendable>: ObservableObject {
    public typealias FetchResult = (items: [Item], nextPage: Page?)
    public typealias Fetch = (Page) async throws -> FetchResult
    
    // Public
    @Published public private(set) var items: [Item] = []
    @Published public private(set) var hasNext: Bool = false
    @Published public private(set) var isLoading: Bool = false
    public var fetchTaskPriority: TaskPriority = .userInitiated
    
    private let _fetch: Fetch
    private let initialPage: Page
    private var currentFetchTask: Task<Void, Error>?
    private var nextPage: Page? {
        didSet { hasNext = (nextPage != nil) }
    }
    private var isFetching: Bool = false {
        didSet { updateLoading() }
    }
    private var isRefreshing: Bool = false {
        didSet { updateLoading() }
    }
    
    public init(initialPage: Page, fetch: @escaping Fetch) {
        self.initialPage = initialPage
        self._fetch = fetch
    }
    
    public func initiate() async throws(PaginatorError) {
        try await refresh()
    }
    
    public func refresh() async throws(PaginatorError) {
        guard !isRefreshing else { throw .isLoading }
        defer { isRefreshing = false }
        isRefreshing = true
        
        await cancelAndWait()
        
        // 취소 대기후 Task취소 여부 확인
        guard !Task.isCancelled else { throw .taskIsCancelled }
        
        try await fetch(initialPage) { [weak self] fetchResult in
            // replace
            self?.items = fetchResult.items
            self?.nextPage = fetchResult.nextPage
        }
    }
    
    public func fetchNext() async throws(PaginatorError) {
        guard !isRefreshing else { throw .isLoading }
        guard let nextPage else { throw .noMorePages }
        
        try await fetch(nextPage) { [weak self] fetchResult in
            // appending
            self?.items += fetchResult.items
            self?.nextPage = fetchResult.nextPage
        }
    }
    
    private func fetch(
        _ page: Page,
        handleResult: @escaping (FetchResult) -> Void
    ) async throws(PaginatorError) {
        guard !isFetching else { throw .isLoading }
        isFetching = true
        
        let task = Task<Void, Error>(priority: fetchTaskPriority) { [weak self] in
            guard let self else { return }
            defer {
                currentFetchTask = nil
                isFetching = false
            }
            do {
                let fetchResult = try await _fetch(page)
                // withTaskCancellationHandler에 의해 취소된 경우
                // handleResult가 실행되지 않습니다.
                try Task.checkCancellation()
                handleResult(fetchResult)
            } catch is CancellationError {
                throw PaginatorError.taskIsCancelled
            } catch {
                throw PaginatorError.fetchFailure(underlyingError: error)
            }
        }
        currentFetchTask = task
        
        do {
            // 현재 함수를 실행하는 상위 Task가 취소된 경우 생성한 Task에 취소를 전파합니다.
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch let error as PaginatorError {
            throw error
        } catch {
            throw PaginatorError.unknown(error: error)
        }
    }
    
    private func cancelAndWait() async {
        guard let currentFetchTask else { return }
        currentFetchTask.cancel()
        // 단순 대기이기 때문에 실패사유는 무시합니다.
        _ = try? await currentFetchTask.value
    }
    
    private func updateLoading() {
        isLoading = isFetching || isRefreshing
    }
}
