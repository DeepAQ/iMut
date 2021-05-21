import NetworkExtension

class TunnelManager {
    private static var manager: NETunnelProviderManager?

    static func start() {
        doWithManager { manager in
            manager.isEnabled = true
            manager.saveToPreferences { error in
                guard error == nil else {
                    NSLog(String(describing: error))
                    return
                }

                manager.loadFromPreferences { error in
                    guard error == nil else {
                        NSLog(String(describing: error))
                        return
                    }

                    switch manager.connection.status {
                    case .invalid, .disconnected:
                        do {
                            try manager.connection.startVPNTunnel()
                        } catch {
                            NSLog(String(describing: error))
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
                    NSLog(String(describing: error))
                    return
                }

                let confManager = ConfigManager.global
                confManager.globalSetting.alwaysOn = alwaysOn
                confManager.saveGlobalSetting()
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
                NSLog(String(describing: error))
                return
            }

            var manager: NETunnelProviderManager
            if let managers = managers, managers.count > 0 {
                manager = managers[0]
            } else {
                manager = NETunnelProviderManager()
                manager.protocolConfiguration = NETunnelProviderProtocol()
                manager.protocolConfiguration?.serverAddress = "Mut"
            }
            self.manager = manager
            action(manager)
        }
    }
}
