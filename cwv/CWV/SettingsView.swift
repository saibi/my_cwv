import SwiftUI

func zoomStepper(_ title: String, _ zoom: Binding<Double>) -> some View {
    Stepper("\(title) \(Int((zoom.wrappedValue * 100).rounded()))%", value: Binding(get: { zoom.wrappedValue }, set: { zoom.wrappedValue = clampZoom($0) }),
            in: zoomRange, step: 0.1)
}

struct SettingsView: View {
    @EnvironmentObject var store: SiteStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("새로 추가하는 사이트와, 확대%가 없는 CSV 줄에 적용됩니다. 이미 있는 사이트는 바뀌지 않습니다.")) {
                    zoomStepper("기본 확대", $store.defaultZoom)
                }
            }
            .navigationTitle("옵션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        }
    }
}
