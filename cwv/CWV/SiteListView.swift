import SwiftUI

private struct EditTarget: Identifiable {
    let id = UUID()
    let existing: Site?
}

struct SiteListView: View {
    @EnvironmentObject var store: SiteStore
    let onOpen: (Site) -> Void
    var selectedID: UUID?  // 분할 화면에서 지금 열린 사이트 (강조)
    var onHide: (() -> Void)?  // 분할 화면의 목록 숨기기 버튼
    @AppStorage(SidebarKey.side) private var side = SidebarSide.leading
    @State private var editing: EditTarget?
    @State private var confirmReset = false
    @State private var pendingImport: CSVImport?
    @State private var exporting = false
    @State private var importing = false
    @State private var message: String?
    @State private var exportText = ""
    @State private var showSettings = false

    /// 다른 기기에서 만든 백업이고 데스크톱으로 지정된 사이트가 있어 선택지를 보여 줄 때.
    private func foreign(_ imp: CSVImport) -> Bool {
        imp.device != nil && imp.device != Self.device && imp.sites.contains { $0.desktop }
    }

    /// iPad에서 복원할 때만 파일의 분할 화면 설정을 적용한다 (iPhone에는 그 설정이 없다).
    private func appliesSidebar(_ imp: CSVImport) -> Bool { Self.device == .ipad && !imp.sidebar.isEmpty }

    private func restore(_ imp: CSVImport, sites: [Site]) {
        store.replace(with: sites)
        if appliesSidebar(imp) { SidebarLayout.apply(imp.sidebar) }
    }

    private func delete(_ site: Site) {
        if let i = store.sites.firstIndex(of: site) { store.remove(at: [i]) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.sites) { site in
                    SiteRow(site: site, onOpen: onOpen, onEdit: { editing = EditTarget(existing: site) })
                        .listRowBackground(site.id == selectedID ? Color.accentColor.opacity(0.18) : nil)
                        .contextMenu {
                            Button("편집", systemImage: "pencil") { editing = EditTarget(existing: site) }
                            Button("삭제", systemImage: "trash", role: .destructive) { delete(site) }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("삭제", role: .destructive) { delete(site) }
                            Button("편집") { editing = EditTarget(existing: site) }.tint(.blue)
                        }
                }
                .onMove { store.sites.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { store.remove(at: $0) }
            }
            .frame(maxWidth: 700)  // iPad 등 넓은 화면에서 목록이 끝까지 늘어나지 않게 가운데 정렬
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .overlay { if store.sites.isEmpty { Text("오른쪽 위 +로 추가하거나 ... 메뉴에서 기본값으로 초기화하세요").foregroundStyle(.secondary).padding() } }
            .navigationTitle("커뮤니티")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let onHide { Button(action: onHide) { Image(systemName: side == .leading ? "sidebar.left" : "sidebar.right") }.accessibilityLabel("목록 숨기기") }
                    Menu {
                        Button("옵션", systemImage: "gearshape") { showSettings = true }
                        Divider()
                        Button("CSV로 백업 (파일 앱에 저장)") { startExport() }
                        Button("CSV에서 복원 (파일 앱에서 선택)") { importing = true }
                        Divider()
                        Button("기본값으로 초기화", role: .destructive) { confirmReset = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                    Button { editing = EditTarget(existing: nil) } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { SiteEditView(existing: $0.existing) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fileExporter(isPresented: $exporting, document: CSVDocument(text: exportText),
                          contentType: .commaSeparatedText, defaultFilename: backupFileName(date: Self.today, device: Self.device)) { result in
                switch result {
                case .success: message = "백업했습니다. 파일 앱에서 저장한 위치를 확인하세요."
                case .failure(let e): message = "백업하지 못했습니다: \(e.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                handleImport(result)
            }
            .confirmationDialog("기본값으로 초기화", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("초기화", role: .destructive) { store.reset() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("현재 목록이 사라지고 앱에 들어 있는 기본 목록으로 바뀝니다. 확대%는 기본 목록 파일에 적힌 값(없으면 기본 확대% \(Int((store.defaultZoom * 100).rounded()))%)이 됩니다.")
            }
            .confirmationDialog("파일 내용으로 교체", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                                titleVisibility: .visible, presenting: pendingImport) { imp in
                Button(foreign(imp) ? "그대로 복원" : "교체", role: .destructive) { restore(imp, sites: imp.sites) }
                if foreign(imp) { Button("데스크톱 설정은 빼고 복원", role: .destructive) { restore(imp, sites: withoutDesktop(imp.sites)) } }
                Button("취소", role: .cancel) {}
            } message: { imp in
                Text((foreign(imp) ? "\(imp.device == .ipad ? "iPad" : "iPhone")에서 백업한 파일입니다. 사이트별 데스크톱 설정이 이 기기에도 적용됩니다. " : "")
                     + (appliesSidebar(imp) ? "분할 화면의 목록 위치/너비도 파일 값으로 바뀝니다. " : "")
                     + "현재 목록 \(store.sites.count)개가 파일의 \(imp.sites.count)개로 바뀝니다." + (imp.skipped > 0 ? " (잘못된 주소 또는 중복 \(imp.skipped)줄은 건너뜀)" : "") + " 확대%는 파일에 적힌 값(없으면 기본 확대% \(Int((store.defaultZoom * 100).rounded()))%)이 됩니다.")
            }
            .alert("알림", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("확인") {}
            } message: { Text(message ?? "") }
        }
    }

    private func describe(_ e: CSVImportError, backup: Bool) -> String {
        switch e {
        case .tooLarge: return backup ? "목록이 너무 커서 백업할 수 없습니다 (복원 가능한 최대 1MB)." : "파일이 너무 큽니다 (최대 1MB)."
        case .tooManyLines: return backup ? "사이트가 너무 많아 백업할 수 없습니다 (복원 가능한 최대 \(csvImportMaxLines)개). 일부를 지운 뒤 다시 시도하세요." : "줄이 너무 많습니다 (최대 \(csvImportMaxLines)개)."
        case .notUTF8: return "UTF-8 텍스트 파일이 아닙니다."
        case .noValidLines: return "올바른 주소가 한 줄도 없어 목록을 바꾸지 않았습니다."
        }
    }

    /// 복원할 수 있는 크기일 때만 파일 저장 창을 연다.
    private func startExport() {
        switch store.exportCSV(device: Self.device, layout: Self.device == .ipad ? SidebarLayout.load() : nil) {
        case .success(let text): exportText = text; exporting = true
        case .failure(let e): message = describe(e, backup: true)
        }
    }

    /// 지금 기기 (백업 파일 이름과 헤더에 남긴다).
    private static var device: CSVDevice { UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone }

    private static var today: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// 파일 앱에서 고른 CSV를 검사하고 교체 확인창으로 넘긴다. 외부 파일이므로 크기를 먼저 보고 읽는다.
    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            if case .failure(let e) = result { message = "파일을 열지 못했습니다: \(e.localizedDescription)" }
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = readLimited(url) else { message = "파일을 읽지 못했습니다."; return }
        switch importCSV(data, defaultZoom: store.defaultZoom, fileName: url.lastPathComponent) {
        case .success(let imp): pendingImport = imp
        case .failure(let e): message = describe(e, backup: false)
        }
    }
}

/// 목록의 한 행. 편집 모드에서 탭하면 열기 대신 편집 (편집 모드는 List 안쪽 뷰에서만 읽을 수 있다).
private struct SiteRow: View {
    @EnvironmentObject var store: SiteStore
    @Environment(\.editMode) private var editMode
    let site: Site
    let onOpen: (Site) -> Void
    let onEdit: () -> Void

    var body: some View {
        Button { editMode?.wrappedValue.isEditing == true ? onEdit() : onOpen(site) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.title(for: site)).font(.headline)
                Text(site.url.absoluteString).font(.caption).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }
}

struct SiteEditView: View {
    @EnvironmentObject var store: SiteStore
    @Environment(\.dismiss) private var dismiss
    let existing: Site?
    @State private var name = ""
    @State private var urlText = ""
    @State private var zoom = initialDefaultZoom
    @State private var desktop = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("이름 (비우면 페이지 제목)", text: $name)
                TextField("주소 (예: damoang.net/empathy)", text: $urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                zoomStepper("확대", $zoom)
                Toggle("데스크톱 사이트로 보기", isOn: $desktop)
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle(existing == nil ? "사이트 추가" : "사이트 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장", action: save) }
            }
            .onAppear {
                name = existing?.name ?? ""
                urlText = existing?.url.absoluteString ?? ""
                zoom = existing?.zoom ?? store.defaultZoom
                desktop = existing?.desktop ?? false
            }
        }
    }

    private func save() {
        guard let url = normalizeURL(urlText) else {
            error = "http 또는 https 주소를 입력하세요"
            return
        }
        let n = name.trimmingCharacters(in: .whitespaces)
        let finalName = n  // 비우면 ""(자동: 페이지 타이틀 -> 도메인)
        if var s = existing {
            s.name = finalName
            s.url = url
            s.zoom = zoom
            s.desktop = desktop
            store.update(s)
        } else {
            store.add(name: finalName, url: url, zoom: zoom, desktop: desktop)
        }
        dismiss()
    }
}
