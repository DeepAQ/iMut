import os
import SwiftUI

struct LogView: View {
    @State private var text = "Logs will display here"
    @State private var loading = false
    
    var body: some View {
        ScrollView {
            Text(text)
                .lineLimit(nil)
                .font(.system(size: 14, design: .monospaced))
        }.padding(.horizontal, 20)
            .navigationBarTitle("Logs")
            .navigationBarItems(trailing:
            Button(action: {
                self.loading = true
                TunnelManager.sendMessage(messageData: "getlogs".data(using: .utf8)!) { result in
                    self.loading = false
                    if let result = result {
                        self.text = String(data: result, encoding: .utf8)!
                    }
                }
            }) {
                if loading {
                    ProgressView()
                }
                Text("Refresh")
            }).disabled(loading)
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
