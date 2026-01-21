//
//  RootProvider.swift
//  Retriever
//

import CoreFlow

struct RootProvider {
    func provide(_ serviceLocator: ServiceLocator) {
        // Root에서 사용할 의존성 등록
        guard let _ = 1 as? Int else { return }
    }
}
