import Foundation
import os

class ConfigManager: ObservableObject {
    static let global = ConfigManager()

    private let userDefaults = UserDefaults()
    @Published var globalSetting: GlobalSetting
    @Published var configurations: [Configuration]
    @Published var selectedIndex: Int

    private init() {
        self.globalSetting = GlobalSetting(
                alwaysOn: self.userDefaults.bool(forKey: "alwaysOn"),
                bypassSpecial: self.userDefaults.bool(forKey: "bypassSpecial"),
                bypassLocalRoute: self.userDefaults.bool(forKey: "bypassLocalRoute"),
                tunOnly: self.userDefaults.bool(forKey: "tunOnly"),
                allowDebug: self.userDefaults.bool(forKey: "allowDebug")
        )

        if let json = self.userDefaults.string(forKey: "configurations")?.data(using: .utf8),
           let configurations = try? JSONDecoder().decode([Configuration].self, from: json) {
            self.configurations = configurations
        } else {
            self.configurations = [Configuration]()
        }
        self.selectedIndex = self.userDefaults.integer(forKey: "selected")
    }

    func saveGlobalSetting() {
        self.userDefaults.set(self.globalSetting.alwaysOn, forKey: "alwaysOn")
        self.userDefaults.set(self.globalSetting.bypassSpecial, forKey: "bypassSpecial")
        self.userDefaults.set(self.globalSetting.bypassLocalRoute, forKey: "bypassLocalRoute")
        self.userDefaults.set(self.globalSetting.tunOnly, forKey: "tunOnly")
        self.userDefaults.set(self.globalSetting.allowDebug, forKey: "allowDebug")
        self.userDefaults.synchronize()
        TunnelManager.updateConfig(confManager: self)
    }

    func saveConfigurations() {
        do {
            let json = String(data: try JSONEncoder().encode(self.configurations), encoding: .utf8)
            self.userDefaults.set(json, forKey: "configurations")
            self.userDefaults.synchronize()
            self.updateSelected()
        } catch {
            os_log(.error, "Failed to save configurations: %{public}s", String(describing: error))
        }
    }

    func setSelectedIndex(index: Int) {
        self.selectedIndex = index
        self.updateSelected()
    }

    private func updateSelected() {
        if self.selectedIndex < configurations.count {
            self.userDefaults.set(self.selectedIndex, forKey: "selected")
            self.userDefaults.synchronize()
            TunnelManager.updateConfig(confManager: self)
        }
    }
}

struct Configuration: Hashable, Codable {
    var name: String
    var outbound: String
    var dns: String?
}

struct GlobalSetting: Hashable, Codable {
    var alwaysOn: Bool
    var bypassSpecial: Bool
    var bypassLocalRoute: Bool
    var tunOnly: Bool
    var allowDebug: Bool
}
