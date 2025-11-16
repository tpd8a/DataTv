//
//  Persistence.swift
//  SplTv
//
//  Created by Peter Moore on 08/11/2025.
//

import CoreData

/// Persistence controller for SplTV
/// Uses DashboardKit's CoreData manager directly
struct PersistenceController {
    // Deprecated - use DashboardKit.manager instead
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Load DashboardKit's CoreData model from the package
        let modelName = "DashboardModel"

        // Try to find the model in DashboardKit bundle
        var modelURL: URL?

        // Check in main bundle first (when DashboardKit is linked)
        if let url = Bundle.main.url(forResource: modelName, withExtension: "momd") {
            modelURL = url
        }

        guard let url = modelURL,
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Failed to load DashboardKit CoreData model '\(modelName)'")
        }

        container = NSPersistentContainer(name: "SplTv", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // In production, handle this error gracefully
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Get the managed object context
    var context: NSManagedObjectContext {
        return container.viewContext
    }
}
