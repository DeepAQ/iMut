import SwiftUI
import NetworkExtension

struct ContentView: View {
    @StateObject private var confManager = ConfigManager.global

    private class ContentViewState: ObservableObject {
        @Published var status = NEVPNStatus.invalid
    }

    @StateObject private var state = ContentViewState()
    @State private var showNewConfigView = false

    var body: some View {
        let toggleConnect = Binding<Bool>(get: {
            let status = self.state.status
            return status == .connected || status == .connecting || status == .reasserting
        }, set: { newValue in
            if newValue {
                TunnelManager.start()
            } else {
                TunnelManager.stop()
            }
        })

        let toggleAlwaysOn = Binding<Bool>(get: {
            return self.confManager.globalSetting.alwaysOn
        }, set: { newValue in
            TunnelManager.setAlwaysOn(newValue)
        })

        let toggleBypassSpecial = Binding<Bool>(get: {
            return self.confManager.globalSetting.bypassSpecial
        }, set: { newValue in
            self.confManager.globalSetting.bypassSpecial = newValue
            self.confManager.saveGlobalSetting()
        })

        let toggleAllowDebug = Binding<Bool>(get: {
            return self.confManager.globalSetting.allowDebug
        }, set: { newValue in
            self.confManager.globalSetting.allowDebug = newValue
            self.confManager.saveGlobalSetting()
        })

        NavigationView {
            VStack {
                HStack {
                    HStack(alignment: .bottom) {
                        Text("iMut").font(.system(size: 32, weight: .bold, design: .monospaced))
                        Text("a DeepAQ Labs project").font(.system(size: 14)).padding(.bottom, 5)
                    }
                    Spacer()
                    Toggle(isOn: toggleConnect) {
                    }.labelsHidden()
                }.padding(.horizontal, 20)

                Form {
                    Section(header: Text("Configurations")) {
                        ForEach(self.confManager.configurations.indices, id: \.self) { i in
                            ConfigItemView(index: i)
                        }.onDelete(perform: { iSet in
                            if iSet.contains(self.confManager.selectedIndex) {
                                self.confManager.setSelectedIndex(index: 0)
                            }
                            self.confManager.configurations.remove(atOffsets: iSet)
                            self.confManager.saveConfigurations()
                        })

                        NavigationLink(destination: ConfigEditView(show: $showNewConfigView, index: -1), isActive: $showNewConfigView) {
                            HStack {
                                Image(systemName: "plus").foregroundColor(.accentColor)
                                Text("Add new configuration")
                            }
                        }
                    }

                    Section(header: Text("Settings")) {
                        Toggle(isOn: toggleAlwaysOn, label: {
                            VStack(alignment: .leading) {
                                Text("Always on")
                                Text("Allow automatic restart").foregroundColor(.secondary)
                            }
                        })
                        Toggle(isOn: toggleBypassSpecial, label: {
                            VStack(alignment: .leading) {
                                Text("Bypass special addresses")
                                Text("DDDD").foregroundColor(.secondary)
                            }
                        })
                        Toggle(isOn: toggleAllowDebug, label: {
                            VStack(alignment: .leading) {
                                Text("Allow debugging")
                                Text("Enable debug HTTP server on localhost:6061").foregroundColor(.secondary)
                            }
                        })
                    }
                }
            }.navigationBarHidden(true)
        }.navigationViewStyle(StackNavigationViewStyle())
                .onAppear {
                    TunnelManager.subscribeStatusUpdate(self.updateStatus)
                }
    }

    private func updateStatus(_ status: NEVPNStatus) {
        self.state.status = status
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
