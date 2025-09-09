import Foundation
import ServiceManagement

class AutoStartService: ObservableObject {
    @Published var isAutoStartEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoStartEnabled, forKey: "AutoStartEnabled")
            updateAutoStartSetting()
        }
    }
    
    private let bundleIdentifier = "app.eweren.timetracker"
    
    init() {
        self.isAutoStartEnabled = UserDefaults.standard.bool(forKey: "AutoStartEnabled")
    }
    
    private func updateAutoStartSetting() {
        do {
            if isAutoStartEnabled {
                // Register the app to launch at login
                try SMAppService.mainApp.register()
            } else {
                // Unregister the app from launching at login
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update auto-start setting: \(error)")
            // Revert the setting if the operation failed
            DispatchQueue.main.async {
                self.isAutoStartEnabled = !self.isAutoStartEnabled
            }
        }
    }
    
    func toggleAutoStart() {
        isAutoStartEnabled.toggle()
    }
    
    func checkAutoStartStatus() -> Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled
    }
}
