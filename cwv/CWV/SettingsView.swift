import SwiftUI

func zoomStepper(_ title: String, _ zoom: Binding<Double>) -> some View {
    Stepper("\(title) \(Int((zoom.wrappedValue * 100).rounded()))%", value: Binding(get: { zoom.wrappedValue }, set: { zoom.wrappedValue = clampZoom($0) }),
            in: zoomRange, step: 0.1)
}

struct SettingsView: View {
    @EnvironmentObject var store: SiteStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SidebarKey.side) private var side = SidebarSide.leading
    @AppStorage(SidebarKey.width) private var sidebarWidth = sidebarDefaultWidth

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("새로 추가하는 사이트와, 확대%가 없는 CSV 줄에 적용됩니다. 이미 있는 사이트는 바뀌지 않습니다.")) {
                    zoomStepper("기본 확대", $store.defaultZoom)
                }
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Section(header: Text("iPad 분할 화면"), footer: Text("넓은 화면에서 목록과 사이트를 같이 보입니다. 너비는 목록과 사이트 사이의 경계를 끌어서 바꿉니다.")) {
                        Picker("목록 위치", selection: $side) {
                            Text("왼쪽").tag(SidebarSide.leading)
                            Text("오른쪽").tag(SidebarSide.trailing)
                        }.pickerStyle(.segmented)
                        Button("목록 너비 기본값으로 (\(Int(sidebarDefaultWidth))pt)") { sidebarWidth = sidebarDefaultWidth }
                            .disabled(sidebarWidth == sidebarDefaultWidth)
                    }
                }
            }
            .navigationTitle("옵션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        }
    }
}
