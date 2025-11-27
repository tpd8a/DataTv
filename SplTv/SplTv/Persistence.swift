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
        // Delegate to CoreDataManager - don't create duplicate container
        // This ensures a single NSPersistentContainer instance across the app
        container = CoreDataManager.shared.persistentContainer
    }

    /// Get the managed object context
    var context: NSManagedObjectContext {
        return CoreDataManager.shared.viewContext
    }
}
