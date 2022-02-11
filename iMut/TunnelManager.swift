import NetworkExtension
import os

class TunnelManager {
    private static var manager: NETunnelProviderManager?

    static func start() {
        doWithManager { manager in
            manager.isEnabled = true
            manager.saveToPreferences { error in
                guard error == nil else {
                    os_log(.error, "Failed to save preferences: %{public}s", String(describing: error))
                    return
                }

                manager.loadFromPreferences { error in
                    guard error == nil else {
                        os_log(.error, "Failed to load preferences: %{public}s", String(describing: error))
                        return
                    }

                    switch manager.connection.status {
                    case .invalid, .disconnected:
                        do {
                            try manager.connection.startVPNTunnel()
                        } catch {
                            os_log(.error, "Failed to start tunnel: %{public}s", String(describing: error))
                        }
                    default:
                        break
                    }
                }
            }
        }
    }

    static func stop() {
        doWithManager { manager in
            if manager.isEnabled {
                manager.connection.stopVPNTunnel()
            }

            NotificationCenter.default.removeObserver(
                    self,
                    name: NSNotification.Name.NEVPNStatusDidChange,
                    object: manager.connection
            )
        }
    }

    static func subscribeStatusUpdate(_ updateListener: @escaping (NEVPNStatus) -> Void) {
        doWithManager { manager in
            updateListener(manager.connection.status)

            NotificationCenter.default.addObserver(
                    forName: NSNotification.Name.NEVPNStatusDidChange,
                    object: manager.connection,
                    queue: OperationQueue.main
            ) { _ in
                updateListener(manager.connection.status)
            }
        }
    }
    
    static func updateConfig(confManager: ConfigManager) {
        doWithManager { manager in
            let proto = manager.protocolConfiguration as! NETunnelProviderProtocol
            var config = proto.providerConfiguration ?? [String: Any]()
            
            let globalSetting = Mirror(reflecting: confManager.globalSetting)
            for setting in globalSetting.children {
                if let key = setting.label {
                    config[key] = setting.value
                }
            }
            if confManager.selectedIndex < confManager.configurations.count && confManager.selectedIndex >= 0 {
                let outboundSetting = Mirror(reflecting: confManager.configurations[confManager.selectedIndex])
                for setting in outboundSetting.children {
                    if let key = setting.label {
                        config[key] = setting.value
                    }
                }
            }
            
            proto.providerConfiguration = config
            manager.saveToPreferences { error in
                os_log(.error, "Failed to save preferences: %{public}s", String(describing: error))
            }
        }
    }

    static func setAlwaysOn(_ alwaysOn: Bool) {
        doWithManager { manager in
            manager.isOnDemandEnabled = alwaysOn
            if alwaysOn {
                let rule = NEOnDemandRuleConnect()
                rule.interfaceTypeMatch = .any
                manager.onDemandRules = [rule]
            }

            manager.saveToPreferences { error in
                guard error == nil else {
                    os_log(.error, "Failed to save preferences: %{public}s", String(describing: error))
                    return
                }
                
                let confManager = ConfigManager.global
                confManager.globalSetting.alwaysOn = alwaysOn
                confManager.saveGlobalSetting()
            }
        }
    }
    
    static func sendMessage(messageData: Data, responseHandler: ((Data?) -> Void)? = nil) {
        doWithManager { manager in
            let session = manager.connection as? NETunnelProviderSession
            if session?.status == .connected {
                do {
                    try session!.sendProviderMessage(messageData, responseHandler: responseHandler)
                } catch {
                    responseHandler?(String(describing: error).data(using: .utf8))
                }
            } else {
                responseHandler?("Tunnel not running".data(using: .utf8))
            }
        }
    }

    private static func doWithManager(action: @escaping (NETunnelProviderManager) -> Void) {
        if let manager = self.manager {
            action(manager)
            return
        }

        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            guard error == nil else {
                os_log(.error, "Failed to load preferences: %{public}s", String(describing: error))
                return
            }

            var manager: NETunnelProviderManager
            if let managers = managers, managers.count > 0 {
                manager = managers[0]
            } else {
                manager = NETunnelProviderManager()
            }
            if !(manager.protocolConfiguration is NETunnelProviderProtocol) {
                manager.protocolConfiguration = NETunnelProviderProtocol()
            }
            manager.protocolConfiguration?.serverAddress = "Mut"
            self.manager = manager
            action(manager)
        }
    }
}
