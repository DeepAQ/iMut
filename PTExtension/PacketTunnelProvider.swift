import Core
import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    private static let mtu = 1500

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        guard let config = (self.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration else {
            os_log(.error, "Failed to get tunnel configuration")
            completionHandler(NETunnelProviderError(.networkSettingsInvalid))
            return
        }
        
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.0.0.1")
        settings.mtu = NSNumber(value: PacketTunnelProvider.mtu)
        settings.ipv4Settings = NEIPv4Settings(addresses: ["240.0.0.2"], subnetMasks: ["255.255.255.252"])
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        if config["bypassLocalRoute"] as? Bool == true {
            settings.ipv4Settings?.excludedRoutes = [
                NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "255.0.0.0"),
                NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
                NEIPv4Route(destinationAddress: "17.0.0.0", subnetMask: "255.0.0.0"),
                NEIPv4Route(destinationAddress: "100.64.0.0", subnetMask: "255.192.0.0"),
                NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0"),
                NEIPv4Route(destinationAddress: "169.254.0.0", subnetMask: "255.255.0.0"),
                NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
                NEIPv4Route(destinationAddress: "192.0.0.0", subnetMask: "255.255.255.0"),
                NEIPv4Route(destinationAddress: "192.0.2.0", subnetMask: "255.255.255.0"),
                NEIPv4Route(destinationAddress: "192.88.99.0", subnetMask: "255.255.255.0"),
                NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
                NEIPv4Route(destinationAddress: "198.51.100.0", subnetMask: "255.255.255.0"),
                NEIPv4Route(destinationAddress: "203.0.113.0", subnetMask: "255.255.255.0"),
                NEIPv4Route(destinationAddress: "224.0.0.0", subnetMask: "240.0.0.0"),
                NEIPv4Route(destinationAddress: "233.252.0.0", subnetMask: "255.255.255.0"),
                NEIPv4Route(destinationAddress: "240.0.0.0", subnetMask: "240.0.0.0"),
            ]
        }
        settings.dnsSettings = NEDNSSettings(servers: ["240.0.0.2"])
        if config["tunOnly"] as? Bool != true {
            settings.proxySettings = NEProxySettings()
//            settings.proxySettings?.httpEnabled = true
            settings.proxySettings?.httpsEnabled = true
//            settings.proxySettings?.httpServer = NEProxyServer(address: "127.0.0.1", port: 1082)
            settings.proxySettings?.httpsServer = NEProxyServer(address: "127.0.0.1", port: 1082)
        }
        self.setTunnelNetworkSettings(settings) { error in
            guard error == nil else {
                os_log(.error, "Failed to set tunnel network settings: %{public}s", String(describing: error))
                completionHandler(error)
                return
            }

            do {
                try self.startMut(config)
                completionHandler(nil)
            } catch {
                os_log(.error, "Failed to start Mut instance: %{public}s", String(describing: error))
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        guard let handler = completionHandler else {
            return
        }
        
        var result = "unknown command"
        if let cmd = String(data: messageData, encoding: .utf8) {
            do {
                switch cmd {
                case "ping":
                    result = "pong"
                case "getlogs":
                    if #available(iOSApplicationExtension 15.0, *) {
                        let logStore = try OSLogStore(scope: .currentProcessIdentifier)
                        result = ""
                        for entry in try logStore.getEntries().suffix(100).reversed() {
                            result = result + "[" + entry.date.formatted(.iso8601) + "] " + entry.composedMessage + "\n"
                        }
                    } else {
                        result = "Logs are only supported on iOS 15.0+"
                    }
                default:
                    break
                }
            } catch {
                result = String(describing: error)
            }
        }
        handler(result.data(using: .utf8))
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }

    override func wake() {
        // Add code here to wake up.
    }

    private func startMut(_ config: [String: Any]) throws {
        let outbound = config["outbound"] as? String ?? "direct://"
        let dns = config["dns"] as? String ?? "udp://1.1.1.1/"
        let bypassSpecial = config["bypassSpecial"] as? Bool ?? false
        let allowDebug = config["allowDebug"] as? Bool ?? false

//        GlobalSetGCPercent(1)
//        GlobalUseDefaultLogger()
//        GlobalSetFreeMemoryInterval(60)
        GlobalSetTcpStreamTimeout(60)
        GlobalSetUdpStreamTimeout(30)

        let launcher = CoreLauncher()
        launcher.addArg("-in")
        launcher.addArg("mix://localhost:1082/?udp=1")
        launcher.addArg("-in")
        launcher.addArg("tun://?fd=\(self.getFd())&mtu=\(PacketTunnelProvider.mtu)&dnsgw=localhost:1053")
        launcher.addArg("-out")
        launcher.addArg(outbound)
        launcher.addArg("-dns")
        launcher.addArg(dns + "?local_listen=localhost:1053&fake_ip=1")
        if bypassSpecial {
            if let path = Bundle.main.url(forResource: "directip", withExtension: "txt")?.path {
                launcher.addArg("-rules")
                launcher.addArg("cidr:\(path),direct;final,default")
            }
        }
        if allowDebug {
            launcher.addArg("-debug")
            launcher.addArg("6061")
        }

        try launcher.runDetached()
        os_log("Mut instance started")

        let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: DispatchQueue.global(qos: .userInteractive))
        memoryPressureSource.setEventHandler {
            os_log("Received memory pressure event %{public}s", String(describing: memoryPressureSource.data))
            GlobalFreeOSMemory()
        }
        memoryPressureSource.activate()
    }

    private func getFd() -> Int32 {
        if let fd = self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            return fd
        } else {
            var buf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
            var len = socklen_t(buf.count)
            let utunPrefix = "utun".utf8CString.dropLast()
            for fd: Int32 in 0...1024 {
                if getsockopt(fd, 2, 2, &buf, &len) == 0 && buf.starts(with: utunPrefix) {
                    return fd
                }
            }
        }

        return -1
    }
}
