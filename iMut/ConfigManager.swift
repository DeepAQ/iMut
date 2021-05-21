import Foundation

class ConfigManager: ObservableObject {
    static let global = ConfigManager()

    private let userDefaults = UserDefaults(suiteName: "group.com.github.mut.iMut")!
    @Published var globalSetting: GlobalSetting
    @Published var configurations: [Configuration]
    @Published var selectedIndex: Int

    private init() {
        self.globalSetting = GlobalSetting(
                alwaysOn: self.userDefaults.bool(forKey: "alwaysOn"),
                bypassSpecial: self.userDefaults.bool(forKey: "bypassSpecial"),
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
        self.userDefaults.set(self.globalSetting.allowDebug, forKey: "allowDebug")
        self.userDefaults.synchronize()
    }

    func saveConfigurations() {
        do {
            let json = String(data: try JSONEncoder().encode(self.configurations), encoding: .utf8)
            self.userDefaults.set(json, forKey: "configurations")
            self.userDefaults.synchronize()
            self.updateSelected()
        } catch {
            NSLog("Failed to save configurations: \(error)")
        }
    }

    func setSelectedIndex(index: Int) {
        self.selectedIndex = index
        self.updateSelected()
    }

    private func updateSelected() {
        if self.selectedIndex < configurations.count {
            self.userDefaults.set(self.selectedIndex, forKey: "selected")
            self.userDefaults.set(self.configurations[self.selectedIndex].outbound, forKey: "outbound")
            self.userDefaults.set(self.configurations[self.selectedIndex].dns, forKey: "dns")
            self.userDefaults.synchronize()
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
    var allowDebug: Bool
}
