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
    @AppStorage(joystickCmKey) private var joystickCm = defaultJoystickCm

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("새로 추가하는 사이트와, 확대%가 없는 CSV 줄에 적용됩니다. 이미 있는 사이트는 바뀌지 않습니다.")) {
                    zoomStepper("기본 확대", $store.defaultZoom)
                }
                Section(header: Text("조이스틱"), footer: Text("플로팅 버튼을 누른 채 이 거리 이상 끌었다 놓으면 뒤로/앞으로/글자 크기가 동작합니다. 모서리 이동은 5배 거리입니다. 기기마다 따로 저장됩니다.")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("감도")
                            Spacer()
                            Text(String(format: "%.2fcm", clampJoystickCm(joystickCm))).monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(get: { clampJoystickCm(joystickCm) }, set: { joystickCm = clampJoystickCm($0) }),
                               in: joystickCmRange, step: joystickCmStep) {
                            Text("조이스틱 감도")
                        } minimumValueLabel: {
                            Text("민감").font(.caption)
                        } maximumValueLabel: {
                            Text("둔감").font(.caption)
                        }
                    }
                    Button("기본값으로 (\(String(format: "%.1f", defaultJoystickCm))cm)") { joystickCm = defaultJoystickCm }
                        .disabled(clampJoystickCm(joystickCm) == defaultJoystickCm)
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
