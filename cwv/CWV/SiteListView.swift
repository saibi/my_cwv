import SwiftUI

private struct EditTarget: Identifiable {
    let id = UUID()
    let existing: Site?
}

struct SiteListView: View {
    @EnvironmentObject var store: SiteStore
    let onOpen: (Site) -> Void
    @State private var editing: EditTarget?
    @State private var confirmReset = false
    @State private var pendingImport: CSVImport?
    @State private var exporting = false
    @State private var importing = false
    @State private var message: String?

    private func row(_ site: Site) -> some View {
        Button { onOpen(site) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.title(for: site)).font(.headline)
                Text(site.url.absoluteString).font(.caption).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.sites) { site in
                    row(site)
                        .swipeActions(edge: .trailing) {
                            Button("삭제", role: .destructive) {
                                if let i = store.sites.firstIndex(of: site) { store.remove(at: [i]) }
                            }
                            Button("편집") { editing = EditTarget(existing: site) }.tint(.blue)
                        }
                }
                .onMove { store.sites.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { store.remove(at: $0) }
            }
            .overlay { if store.sites.isEmpty { Text("오른쪽 위 +로 추가하거나 ... 메뉴에서 기본값으로 초기화하세요").foregroundStyle(.secondary).padding() } }
            .navigationTitle("커뮤니티")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button("CSV로 백업 (파일 앱에 저장)") { exporting = true }
                        Button("CSV에서 복원 (파일 앱에서 선택)") { importing = true }
                        Divider()
                        Button("기본값으로 초기화", role: .destructive) { confirmReset = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                    Button { editing = EditTarget(existing: nil) } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { SiteEditView(existing: $0.existing) }
            .fileExporter(isPresented: $exporting, document: CSVDocument(text: exportCSV(store.sites)),
                          contentType: .commaSeparatedText, defaultFilename: "cwv_sites_\(Self.today)") { result in
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
                Text("현재 목록이 사라지고 앱에 들어 있는 기본 목록으로 바뀝니다. 글자 크기도 100%로 돌아갑니다.")
            }
            .confirmationDialog("파일 내용으로 교체", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                                titleVisibility: .visible, presenting: pendingImport) { imp in
                Button("교체", role: .destructive) { store.replace(with: imp.sites) }
                Button("취소", role: .cancel) {}
            } message: { imp in
                Text("현재 목록 \(store.sites.count)개가 파일의 \(imp.sites.count)개로 바뀝니다." + (imp.skipped > 0 ? " (잘못된 주소 또는 중복 \(imp.skipped)줄은 건너뜀)" : "") + " 글자 크기는 100%가 됩니다.")
            }
            .alert("알림", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("확인") {}
            } message: { Text(message ?? "") }
        }
    }

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
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= csvImportMaxBytes, let data = try? Data(contentsOf: url) else {
            message = size > csvImportMaxBytes ? "파일이 너무 큽니다 (최대 1MB)." : "파일을 읽지 못했습니다."
            return
        }
        switch importCSV(data) {
        case .success(let imp): pendingImport = imp
        case .failure(.tooLarge): message = "파일이 너무 큽니다 (최대 1MB)."
        case .failure(.notUTF8): message = "UTF-8 텍스트 파일이 아닙니다."
        case .failure(.tooManyLines): message = "줄이 너무 많습니다 (최대 \(csvImportMaxLines)개)."
        case .failure(.noValidLines): message = "올바른 주소가 한 줄도 없어 목록을 바꾸지 않았습니다."
        }
    }
}

struct SiteEditView: View {
    @EnvironmentObject var store: SiteStore
    @Environment(\.dismiss) private var dismiss
    let existing: Site?
    @State private var name = ""
    @State private var urlText = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("이름 (비우면 페이지 제목)", text: $name)
                TextField("주소 (예: damoang.net/empathy)", text: $urlText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
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
            store.update(s)
        } else {
            store.add(name: finalName, url: url)
        }
        dismiss()
    }
}
