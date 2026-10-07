# 마이그레이션 규칙

## 스토어 설정

- `shouldMigrateStoreAutomatically`와 `shouldInferMappingModelAutomatically`를 true로 둔다. 둘 다 기본값이 true다.
- 단계가 둘 이상이면 `NSStagedMigrationManager`를 `NSPersistentStoreStagedMigrationManagerOptionKey` 옵션으로 스토어 설명에 등록한다.
- 컨테이너에는 최신 모델을 넘긴다.

### 코드

```swift
func makeContainer() -> NSPersistentContainer {
    // 컨테이너에는 최신 모델을 넘긴다.
    guard
        let url = Bundle.main.url(forResource: "Migration", withExtension: "momd"),
        let destinationModel = NSManagedObjectModel(contentsOf: url)
    else { fatalError("Migration 모델을 찾을 수 없습니다.") }

    let storeURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Migration.sqlite")

    let container = NSPersistentContainer(name: "Migration", managedObjectModel: destinationModel)
    let description = NSPersistentStoreDescription(url: storeURL)

    // 모델과 스토어가 맞지 않을 때 Core Data가 자동 마이그레이션을 시도하게 한다.
    // false면 불일치 상태에서 스토어 로드가 오류로 끝난다.
    description.shouldMigrateStoreAutomatically = true          // 기본값 true
    // 매핑 모델을 찾지 못하면 추론해서 만든다. 위 옵션과 함께 true여야 한다.
    description.shouldInferMappingModelAutomatically = true     // 기본값 true

    do {
        description.setOption(
            try makeStagedMigrationManager(),
            forKey: NSPersistentStoreStagedMigrationManagerOptionKey
        )
    } catch {
        fatalError(error.localizedDescription)
    }
    container.persistentStoreDescriptions = [description]

    var loadError: Error?
    container.loadPersistentStores { _, error in
        loadError = error
    }
    if let loadError {
        fatalError(loadError.localizedDescription)
    }
    container.viewContext.automaticallyMergesChangesFromParent = true
    return container
}
```

## 버전 모델 참조

- 각 버전은 `NSManagedObjectModelReference(fileURL:versionChecksum:)`로 참조한다. 버전마다 `NSManagedObjectModel`을 직접 로드하면 같은 클래스를 여러 엔티티가 차지한다. (stack.md 참고)
- 체크섬은 컴파일된 momd 안의 `VersionInfo.plist`에 있는 `NSManagedObjectModel_VersionChecksums`에서 읽는다.
- 현재 스토어가 어느 버전인지는 `metadataForPersistentStore(type:at:)`의 `NSPersistentStoreModelVersionChecksumKey`로 확인한다. 스토어를 열지 않고 읽을 수 있다.

### 코드

```swift
// Migration.xcdatamodeld 안의 버전 이름: Migration, Migration_v2, ..., Migration_v5
private enum ModelVersion {
    static let v1 = reference(name: "Migration")
    static let v2 = reference(name: "Migration_v2")
    static let v3 = reference(name: "Migration_v3")
    static let v4 = reference(name: "Migration_v4")
    static let v5 = reference(name: "Migration_v5")

    private static let momdURL: URL = {
        guard let url = Bundle.main.url(forResource: "Migration", withExtension: "momd") else {
            fatalError("Migration 모델을 찾을 수 없습니다.")
        }
        return url
    }()

    // 컴파일된 momd 안의 VersionInfo.plist에 버전별 체크섬이 들어 있다.
    // Xcode 빌드 로그에 출력되는 "Model ... version checksum" 값과 같다.
    private static let checksums: [String: String] = {
        guard
            let data = try? Data(contentsOf: momdURL.appending(component: "VersionInfo.plist")),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let checksums = plist["NSManagedObjectModel_VersionChecksums"] as? [String: String]
        else { fatalError("VersionInfo.plist에서 체크섬을 읽을 수 없습니다.") }
        return checksums
    }()

    // 스토어 메타데이터의 체크섬이 어느 버전인지 찾는다.
    static func versionName(forChecksum checksum: String) -> String? {
        checksums.first { $0.value == checksum }?.key
    }

    private static func reference(name: String) -> NSManagedObjectModelReference {
        guard let checksum = checksums[name] else { fatalError("\(name) 체크섬이 없습니다.") }
        // NSManagedObjectModel(contentsOf:)로 버전마다 모델을 로드하면 같은 클래스를 가진 모델이 여러 개 생겨
        // "Multiple NSEntityDescriptions claim the NSManagedObject subclass" 경고가 나고
        // fetchRequest()나 init(context:)가 엉뚱한 모델의 엔티티를 고를 수 있다.
        // fileURL 기반 참조는 모델을 즉시 로드하지 않으므로 이 문제를 피한다.
        return NSManagedObjectModelReference(
            fileURL: momdURL.appending(component: "\(name).mom"),
            versionChecksum: checksum
        )
    }
}

// 스토어를 열지 않고 메타데이터에서 현재 스토어의 모델 버전을 확인한다.
func currentStoreVersion(storeURL: URL) throws -> String? {
    guard FileManager.default.fileExists(atPath: storeURL.path) else { return nil }
    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeURL)
    // iOS 18 이상에서 스토어 메타데이터에 기록되는 모델 버전 체크섬 키다.
    guard let checksum = metadata[NSPersistentStoreModelVersionChecksumKey] as? String else { return nil }
    return ModelVersion.versionName(forChecksum: checksum)
}
```

## 스테이지 구성

| 변경 종류 | 스테이지 |
| --- | --- |
| 이름 변경, 옵셔널 속성 추가처럼 추론만으로 되는 변경 | `NSLightweightMigrationStage([출발 버전 체크섬])` |
| 기존 행의 값을 채우거나 옮겨야 하는 변경 | `NSCustomMigrationStage(migratingFrom:to:)` + `willMigrateHandler` |
| 추론만으로 되지만 앞 스테이지가 커스텀이라 경량 스테이지로 둘 수 없는 구간 | 핸들러를 비운 `NSCustomMigrationStage` |

- 이름을 바꾸면 새 모델의 속성에 이전 이름을 Renaming ID로 지정한다.
- Xcode 편집기에서 엔티티의 Renaming ID에 값이 잘못 들어가는 실수가 잦다. `Z<엔티티명> already exists`(예: `ZRECORD already exists`) 오류가 나면 이것부터 확인한다.
- 커스텀 스테이지의 `willMigrateHandler`에서는 `manager.container`로 이전 모델 기준의 임시 컨테이너를 연다. 백그라운드 컨텍스트에서 `NSManagedObject`와 KVC(`value(forKey:)`, `setValue(_:forKey:)`)로 값을 고친 뒤 저장한다. 이전 버전 속성은 생성된 클래스에 없기 때문이다.
- 옵셔널을 필수로 바꾸기 전에 핸들러에서 nil인 행을 모두 채운다. 남아 있으면 스키마 변경이 실패한다.

### 코드

아래 코드는 `Record` 엔티티가 v1부터 v5까지 바뀌는 과정을 다룬다.
마이그레이션 과정을 보여 주기 위해 버전마다 속성 구성이 다르다.

| 버전 | 변경 | 스테이지 |
| --- | --- | --- |
| v1 → v2 | `name`을 `title`로 이름 변경, 옵셔널 `subtitle`, `amount` 추가 | 경량 |
| v2 → v3 | `subtitle`, `amount`를 필수로 변경 | 커스텀 (nil 채우기) |
| v3 → v4 | `headline`을 기본값 빈 문자열로 추가 (expand) | 핸들러 없는 커스텀 |
| v4 → v5 | `title`, `subtitle` 제거 (contract) | 커스텀 (값 옮기기) |

```swift
func makeStagedMigrationManager() throws -> NSStagedMigrationManager {
    let stages: [NSMigrationStage] = [
        // v1 → v2: 이름 변경과 옵셔널 속성 추가만 있어 경량 스테이지로 처리한다.
        // 배열은 "이 스테이지가 출발점으로 삼는 버전들"이다. 스토어가 이 중 하나면 다음 스테이지의 출발 버전까지 경량 마이그레이션한다.
        NSLightweightMigrationStage([ModelVersion.v1.versionChecksum]),
        // v2 → v3: subtitle, amount가 필수로 바뀌므로 핸들러에서 기본값을 채운다.
        fromV2ToV3Stage(),
        // v3 → v4: 추론만으로 처리되지만 v3가 앞 커스텀 스테이지의 도착 버전이라
        // 경량 스테이지 배열에 넣으면 체크섬 중복 예외가 난다. 핸들러 없는 커스텀 스테이지로 잇는다.
        fromV3ToV4Stage(),
        // v4 → v5: title, subtitle을 합쳐 headline을 채운 뒤 두 속성을 제거한다.
        fromV4ToV5Stage(),
    ]
    return NSStagedMigrationManager(stages)
}

func fromV2ToV3Stage() -> NSMigrationStage {
    let stage = NSCustomMigrationStage(migratingFrom: ModelVersion.v2, to: ModelVersion.v3)
    stage.willMigrateHandler = { manager, _ in
        // manager.container는 이전 모델(v2) 기준으로 열린 임시 컨테이너다.
        guard let oldContainer = manager.container else { return }
        let context = oldContainer.newBackgroundContext()
        try context.performAndWait {
            // 이전 버전 속성은 생성된 클래스에 없으므로 NSManagedObject와 KVC로 다룬다.
            let request = NSFetchRequest<NSManagedObject>(entityName: "Record")
            for record in try context.fetch(request) {
                let title = record.value(forKey: "title") as? String ?? ""
                if record.value(forKey: "subtitle") == nil {
                    record.setValue("sub: \(title)", forKey: "subtitle")
                }
                if record.value(forKey: "amount") == nil {
                    record.setValue(0, forKey: "amount")
                }
            }
            try context.save()
        }
        // 핸들러가 끝나면 Core Data가 v2 → v3 스키마 변경을 경량 마이그레이션으로 마무리한다.
    }
    return stage
}

// 스키마 변경만 필요한 구간은 핸들러를 비워 두면 Core Data가 경량 마이그레이션으로 처리한다.
func fromV3ToV4Stage() -> NSMigrationStage {
    NSCustomMigrationStage(migratingFrom: ModelVersion.v3, to: ModelVersion.v4)
}

func fromV4ToV5Stage() -> NSMigrationStage {
    let stage = NSCustomMigrationStage(migratingFrom: ModelVersion.v4, to: ModelVersion.v5)
    stage.willMigrateHandler = { manager, _ in
        // 두 속성이 사라지기 전에 v4 모델 기준으로 값을 옮긴다.
        guard let oldContainer = manager.container else { return }
        let context = oldContainer.newBackgroundContext()
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Record")
            for record in try context.fetch(request) {
                let title = record.value(forKey: "title") as? String ?? ""
                let subtitle = record.value(forKey: "subtitle") as? String ?? ""
                record.setValue("\(title) : \(subtitle)", forKey: "headline")
            }
            try context.save()
        }
    }
    return stage
}
```

## 체크섬 규칙

- 번들에 있는 모든 모델 버전은 어느 스테이지에서든 한 번은 출발 버전으로 등장해야 한다. 빠진 버전의 스토어는 `Incompatible metadata after migration because the store version hashes didn't migrate.` 오류로 열리지 않는다.
  - 커스텀 스테이지의 도착 버전과 다음 커스텀 스테이지의 출발 버전이 다르면 그 사이 버전이 빠진 것이다. 핸들러 없는 커스텀 스테이지로 구간을 잇는다.
- 체크섬은 스테이지 전체에서 중복될 수 없다. 중복되면 `Duplicate version checksums across stages detected.` 예외로 크래시한다.
  - 경량 스테이지 배열에 다음 스테이지의 출발 버전을 넣지 않는다.
  - 경량 스테이지 배열에 앞 커스텀 스테이지의 도착 버전을 넣지 않는다.
  - 그래서 커스텀 스테이지 사이의 자동 마이그레이션 구간은 경량 스테이지로 끼워 넣을 수 없다.
- 커스텀 스테이지끼리는 앞 스테이지의 도착 버전을 다음 스테이지의 출발 버전으로 공유해도 중복으로 잡히지 않는다.

## 컬럼 교체: expand-migrate-contract

속성을 다른 속성으로 교체할 때는 스테이지를 세 단계로 나눈다.

| 단계 | 하는 일 | 위 코드에서 |
| --- | --- | --- |
| expand | 새 속성을 기본값과 함께 추가 | v4: `headline` 추가 |
| migrate | 커스텀 핸들러에서 옛 속성 값을 새 속성으로 채움 | v4 → v5 핸들러 |
| contract | 옛 속성 제거 | v5: `title`, `subtitle` 제거 |

한 스테이지에서 추가와 제거를 함께 하면 옛 값을 읽을 모델이 없어져 값을 옮길 수 없다.

## 사전 점검

- 경량 마이그레이션 가능 여부만 미리 확인하려면 스토어 메타데이터와 최신 모델로 `isConfiguration(withName:compatibleWithStoreMetadata:)`를 확인한다. 호환되지 않으면 `NSManagedObjectModel.mergedModel(from:forStoreMetadata:)`로 출발 모델을 찾고 `NSMappingModel.inferredMappingModel(forSourceModel:destinationModel:)`을 시도한다.

### 코드

```swift
// 추론이 실패하면 에러를 던진다. 성공하면 경량 마이그레이션이 가능하다.
func checkLightweightMigration(storeURL: URL, to destinationModel: NSManagedObjectModel) throws {
    // 스토어 파일이 없는 첫 실행은 마이그레이션 대상이 아니다.
    guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

    // 1. 스토어를 열지 않고 메타데이터를 읽는다.
    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeURL)

    // 2. 이미 최신 모델과 호환되면 마이그레이션이 필요 없다.
    //    withName은 Configuration 이름이고, nil이면 Default다.
    if destinationModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
        return
    }

    // 3. 번들의 모든 모델 버전 중에서 메타데이터와 호환되는 출발 모델을 찾는다.
    if let sourceModel = NSManagedObjectModel.mergedModel(from: [.main], forStoreMetadata: metadata) {
        // 4. 매핑 모델 추론을 시도한다.
        _ = try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        )
    }
}
```
