import Core
import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    private static let mtu = 1500

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.0.0.1")
        settings.mtu = NSNumber(value: PacketTunnelProvider.mtu)
        settings.ipv4Settings = NEIPv4Settings(addresses: ["240.0.0.2"], subnetMasks: ["255.255.255.252"])
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        settings.dnsSettings = NEDNSSettings(servers: ["240.0.0.1"])
        settings.proxySettings = NEProxySettings()
//        settings.proxySettings?.httpEnabled = true
        settings.proxySettings?.httpsEnabled = true
        settings.proxySettings?.httpServer = NEProxyServer(address: "127.0.0.1", port: 1082)
        settings.proxySettings?.httpsServer = settings.proxySettings?.httpServer
        self.setTunnelNetworkSettings(settings) { error in
            guard error == nil else {
                NSLog(String(describing: error))
                completionHandler(error)
                return
            }

            do {
                try self.startMut()
                self.startTunnel()
                completionHandler(nil)
            } catch {
                NSLog(String(describing: error))
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
        if let handler = completionHandler {
            handler(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }

    override func wake() {
        // Add code here to wake up.
    }

    private func startMut() throws {
        let userDefaults = UserDefaults.init(suiteName: "group.com.github.mut.iMut")
        let outbound = userDefaults?.string(forKey: "outbound") ?? "direct://"
        let dns = (userDefaults?.string(forKey: "dns") ?? "udp://1.1.1.1/") + "?local_listen=localhost:1053&fake_ip=1"
        let bypassSpecial = userDefaults?.bool(forKey: "bypassSpecial") ?? false
        let allowDebug = userDefaults?.bool(forKey: "allowDebug") ?? false

        CoreSetGCPercent(1)
        CoreUseDefaultLogger()
        ConfigSetFreeMemoryInterval(60)
        ConfigSetTcpStreamTimeout(60)
        ConfigSetUdpStreamTimeout(30)

        let builder = CoreInstanceBuilder()
        builder.addArg("-in")
        builder.addArg("mix://localhost:1082/?udp=1")
        builder.addArg("-out")
        builder.addArg(outbound)
        builder.addArg("-dns")
        builder.addArg(dns)
        if bypassSpecial {
            if let path = Bundle.main.url(forResource: "directip", withExtension: "txt")?.path {
                builder.addArg("-rules")
                builder.addArg("cidr:\(path),direct;final,default")
            }
        }
        if allowDebug {
            builder.addArg("-debug")
            builder.addArg("6061")
        }

        let instance = try builder.create()
        instance.start()
        NSLog("Mut instance started")

        let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: DispatchQueue.global(qos: .userInteractive))
        memoryPressureSource.setEventHandler {
            NSLog("Received memory pressure event " + String(memoryPressureSource.data))
            switch memoryPressureSource.data {
            case .warning, .critical:
                CoreFreeOSMemory()
            default:
                break
            }
        }
        memoryPressureSource.activate()
    }

    private func startTunnel() {
        let args = [
            "tun2socks",
            "--logger", "syslog",
            "--tunfd", String(self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as! Int32),
            "--tunmtu", String(PacketTunnelProvider.mtu),
            "--enable-udprelay",
            "--netif-ipaddr", "240.0.0.1",
            "--netif-netmask", "255.255.255.252",
            "--socks-server-addr", "127.0.0.1:1082",
            "--dnsgw", "127.0.0.1:1053",
        ]
        var cargs = args.map {
            strdup($0)
        }

        DispatchQueue.global(qos: .default).async {
            tun2socks_main(Int32(cargs.count), &cargs)
            NSLog("Tunnel stopped")
            for ptr in cargs {
                free(ptr)
            }
        }
        NSLog("Tunnel started")
    }
}
