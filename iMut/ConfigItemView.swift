import SwiftUI

struct ConfigItemView: View {
    @StateObject private var confManager = ConfigManager.global
    @State private var showEditView = false
    var index: Int

    var body: some View {
        if self.index < self.confManager.configurations.count {
            HStack {
                if (self.confManager.selectedIndex == self.index) {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                } else {
                    Image(systemName: "checkmark").hidden()
                }

                Button(action: {
                    self.confManager.setSelectedIndex(index: self.index)
                }) {
                    Text(self.confManager.configurations[self.index].name).foregroundColor(.primary)
                }
                Spacer()

                Button(action: {
                    self.showEditView = true
                }) {
                    Image(systemName: "square.and.pencil").foregroundColor(.accentColor)
                }.buttonStyle(BorderlessButtonStyle())

                ScrollView {
                    NavigationLink(destination: ConfigEditView(show: self.$showEditView, index: self.index), isActive: self.$showEditView) {
                    }.fixedSize()
                }.hidden()
            }
        }
    }
}

struct ConfigItemView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigItemView(index: 0)
    }
}
