import Foundation
import DashboardKit

/// Adapter that bridges DashboardKit's DataSource to the interface expected by UI
/// Handles both ds.search and ds.chain types
public struct DataSourceAdapter: Identifiable {
    public let id = UUID()
    public let dataSource: DataSource

    // MARK: - Basic Properties

    public var sourceId: String {
        dataSource.sourceId ?? "unknown"
    }

    public var name: String? {
        dataSource.name
    }

    public var type: String {
        dataSource.type ?? "ds.search"
    }

    public var query: String? {
        dataSource.query
    }

    public var refresh: String? {
        dataSource.refresh
    }

    public var refreshType: String? {
        dataSource.refreshType
    }

    // MARK: - Chaining Properties

    /// ID of the base search this data source chains from (for ds.chain type)
    public var extendsId: String? {
        dataSource.extendsId
    }

    /// Whether this is a chained/post-processing search
    public var isChained: Bool {
        type == "ds.chain" || extendsId != nil
    }

    /// Whether this is a saved search reference
    public var isSavedSearch: Bool {
        type == "ds.savedSearch"
    }

    // MARK: - Display Properties

    /// Display name for the UI
    public var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return sourceId
    }

    /// Icon name based on data source type
    public var iconName: String {
        if isSavedSearch {
            return "bookmark.fill"
        } else if isChained {
            return "link"
        } else {
            return "magnifyingglass"
        }
    }

    /// Color based on data source type
    public var iconColor: String {
        if isSavedSearch {
            return "blue"
        } else if isChained {
            return "orange"
        } else {
            return "secondary"
        }
    }

    /// Description text for the data source
    public var typeDescription: String {
        if isSavedSearch {
            return "Saved Search"
        } else if isChained, let baseId = extendsId {
            return "Post-processes: \(baseId)"
        } else if let refresh = refresh, !refresh.isEmpty {
            return "Refresh: \(refresh)"
        } else {
            return "Static search"
        }
    }

    // MARK: - Initialization

    public init(dataSource: DataSource) {
        self.dataSource = dataSource
    }
}

// MARK: - Collection Helpers

extension Collection where Element == DataSource {
    /// Convert collection of DataSource to DataSourceAdapter array
    public var asAdapters: [DataSourceAdapter] {
        return map { DataSourceAdapter(dataSource: $0) }
    }
}
