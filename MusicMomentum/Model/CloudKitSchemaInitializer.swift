//
//  CloudKitSchemaInitializer.swift
//  MusicMomentum
//

#if DEBUG
import CoreData
import SwiftData

/// Pushes the complete schema for `AppSchema.models` to the CloudKit
/// Development environment, ready to deploy to Production.
///
/// Sync alone only grows Development from records it exports, and a record
/// carries no field for a nil value, so a property nobody happened to set
/// while testing never reaches the schema. Production builds then have
/// records carrying it rejected as a bare `CKErrorDomain error 2`.
/// `initializeCloudKitSchema` covers every entity and attribute in the model
/// by uploading dummy records and deleting them again.
///
/// Debug-only: Apple documents it as a development tool, and it only ever
/// touches the Development environment.
nonisolated enum CloudKitSchemaInitializer {
    enum Failure: LocalizedError {
        case modelUnavailable

        var errorDescription: String? {
            "Couldn't build a Core Data model from the SwiftData schema."
        }
    }

    /// With `dryRun`, validates and prints the schema to the console without
    /// uploading anything. `@concurrent` because the call blocks for as long
    /// as the upload takes.
    @concurrent
    static func run(dryRun: Bool) async throws -> String {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: AppSchema.models) else {
            throw Failure.modelUnavailable
        }

        // A throwaway store, so the dummy records never land in the real one.
        let storeURL = URL.temporaryDirectory.appending(path: "schema-init-\(UUID().uuidString).sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: AppSchema.cloudKitContainer
        )
        let container = NSPersistentCloudKitContainer(name: "SchemaInit", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
        defer {
            try? container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, type: .sqlite)
        }

        var options: NSPersistentCloudKitContainerSchemaInitializationOptions = [.printSchema]
        if dryRun { options.insert(.dryRun) }
        try container.initializeCloudKitSchema(options: options)

        return dryRun
            ? "The model passes CloudKit's rules; the schema is printed in the Xcode console. Nothing was uploaded."
            : "Uploaded to Development for \(AppSchema.cloudKitContainer). Now deploy it in CloudKit Console → Schema → Deploy Schema Changes."
    }
}
#endif
