import SwiftUI
import CoreData
import d8aTvCore

#if os(macOS) || os(tvOS)

/// Dashboard Monitor App
/// Provides a GUI for monitoring and controlling dashboard refresh timers
@available(macOS 26, tvOS 26, *)
@main
struct DashboardMonitorApp: App {
    
    // MARK: - Core Data Context
    
    public let persistenceController = CoreDataManager.shared
    
    
    // MARK: - Scene
    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            DashboardMonitorView()
                .environment(\.managedObjectContext, persistenceController.context)
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            // Add custom menu commands
            CommandGroup(replacing: .newItem) { }
            
            CommandGroup(after: .toolbar) {
                Button("Start All Timers") {
                    DashboardRefreshWorker.shared.startAllRefreshTimers()
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Button("Stop All Timers") {
                    DashboardRefreshWorker.shared.stopAllTimers()
                }
                .keyboardShortcut("s", modifiers: [.command])
                
                Divider()
            }
        }
        
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, persistenceController.context)
        }
        
        #elseif os(tvOS)
        WindowGroup {
            DashboardMonitorView()
                .environment(\.managedObjectContext, persistenceController.context)
        }
        #endif
    }
}

// MARK: - Settings View (macOS only)

#if os(macOS)
@available(macOS 26, *)
struct SettingsView: View {
    
    @AppStorage("autoStartTimers") private var autoStartTimers = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("logRefreshActivity") private var logRefreshActivity = true
    
    var body: some View {
        Form {
            Section("Automatic Refresh") {
                Toggle("Auto-start timers on launch", isOn: $autoStartTimers)
                    .help("Automatically start refresh timers when the app launches")
            }
            
            Section("Notifications") {
                Toggle("Show notifications for refresh errors", isOn: $showNotifications)
                    .help("Display notifications when a search refresh fails")
            }
            
            Section("Logging") {
                Toggle("Log refresh activity", isOn: $logRefreshActivity)
                    .help("Write refresh activity to console logs")
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        autoStartTimers = false
                        showNotifications = true
                        logRefreshActivity = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 300)
        .padding()
    }
}
#endif

#endif
