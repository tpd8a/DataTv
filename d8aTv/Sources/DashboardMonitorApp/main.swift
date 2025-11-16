import SwiftUI
import CoreData
import d8aTvCore
import DashboardMonitorUI

#if os(macOS) || os(tvOS)

/// Dashboard Monitor App
/// Provides a GUI for monitoring and controlling dashboard refresh timers

struct DashboardMonitorApp: App {
    
    // MARK: - Core Data Context
    @MainActor
    public let persistenceController = CoreDataManager.shared
    
    init() {
        print("🚀 DashboardMonitorApp.init() called")
        print("📱 macOS version: \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)")
        print("🗂️ Bundle identifier: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("📦 Bundle path: \(Bundle.main.bundlePath)")
    }
    
    // MARK: - Scene
    var body: some Scene {
        print("🎬 DashboardMonitorApp.body called - about to build scene")
        return buildScene()
    }
    
    @SceneBuilder
    private func buildScene() -> some Scene {
        #if os(macOS)
        WindowGroup {
            DashboardMonitorView()
                .environment(\.managedObjectContext, persistenceController.context)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    print("✅ DashboardMonitorView appeared!")
                }
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
                .onAppear {
                    print("✅ SettingsView appeared!")
                }
        }
        
        #elseif os(tvOS)
        print("📺 Building tvOS scene")
        WindowGroup {
            print("🪟 tvOS WindowGroup body called")
            DashboardMonitorView()
                .environment(\.managedObjectContext, persistenceController.context)
                .onAppear {
                    print("✅ tvOS DashboardMonitorView appeared!")
                }
        }
        #endif
    }
}

// MARK: - Settings View (macOS only)

#if os(macOS)
struct SettingsView: View {
    
    @AppStorage("autoStartTimers") private var autoStartTimers = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("logRefreshActivity") private var logRefreshActivity = true
    
    init() {
        print("⚙️ SettingsView.init() called")
    }
    
    var body: some View {
        print("⚙️ SettingsView.body called")
        return Form {
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
