//
//  Persistence.swift
//  SplTv
//
//  Created by Peter Moore on 08/11/2025.
//

import CoreData
import DashboardKit

/// Persistence controller for SplTV
/// Wrapper around DashboardKit's CoreDataManager
struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        // For previews, we'll use the same shared instance
        // TODO: Implement in-memory store for previews if needed
        return PersistenceController.shared
    }()

    let container: NSPersistentContainer

    private init() {
        // Find the DashboardKit resource bundle
        var foundModel: NSManagedObjectModel?

        // First, try to find the DashboardKit_DashboardKit bundle in the app's Resources
        if let resourceURL = Bundle.main.resourceURL,
           let bundleURL = Bundle(url: resourceURL.appendingPathComponent("DashboardKit_DashboardKit.bundle")),
           let modelURL = bundleURL.url(forResource: "DashboardModel", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: modelURL) {
            foundModel = model
        }

        // Fallback: search all loaded bundles
        if foundModel == nil {
            for bundle in Bundle.allBundles {
                if let url = bundle.url(forResource: "DashboardModel", withExtension: "momd"),
                   let model = NSManagedObjectModel(contentsOf: url) {
                    foundModel = model
                    break
                }
            }
        }

        guard let model = foundModel else {
            fatalError("Failed to load DashboardKit CoreData model 'DashboardModel'. Check that DashboardKit package is properly linked.")
        }

        container = NSPersistentContainer(name: "SplTv", managedObjectModel: model)
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load persistent stores: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Get the managed object context
    var context: NSManagedObjectContext {
        return container.viewContext
    }
}
