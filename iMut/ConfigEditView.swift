import SwiftUI

struct ConfigEditView: View {
    private let confManager = ConfigManager.global

    @Binding private var showSelf: Bool
    @State private var name: String
    @State private var outbound: String
    @State private var dns: String
    private let index: Int

    init(show: Binding<Bool>, index: Int = -1) {
        self._showSelf = show
        self.index = index
        if index < confManager.configurations.count && index >= 0 {
            self.name = confManager.configurations[index].name
            self.outbound = confManager.configurations[index].outbound
            self.dns = confManager.configurations[index].dns ?? ""
        } else {
            self.name = ""
            self.outbound = ""
            self.dns = ""
        }
    }

    var body: some View {
        Form {
            VStack(alignment: .leading) {
                Text("Display name")
                TextField("outbound name", text: self.$name).autocapitalization(.none)
            }.padding(.vertical, 10)

            VStack(alignment: .leading) {
                Text("Outbound URL")
                TextField("protocol://[user:pass@]host:port/?options", text: self.$outbound).autocapitalization(.none)
            }.padding(.vertical, 10)

            VStack(alignment: .leading) {
                Text("DNS server")
                TextField("udp://1.1.1.1/", text: self.$dns).autocapitalization(.none)
            }.padding(.vertical, 10)
        }.navigationBarTitle("Edit configuration")
                .navigationBarItems(trailing:
                Button(action: {
                    if self.index >= 0 && self.index < confManager.configurations.count {
                        confManager.configurations[self.index].name = self.name
                        confManager.configurations[self.index].outbound = self.outbound
                        confManager.configurations[self.index].dns = self.dns
                    } else {
                        confManager.configurations.append(Configuration(name: self.name, outbound: self.outbound, dns: self.dns))
                    }
                    confManager.saveConfigurations()
                    self.showSelf = false
                }) {
                    Text("Done")
                }.disabled(self.name == "" || self.outbound == "")
                )
    }
}

struct ConfigEditView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigEditView(show: .constant(true))
    }
}
