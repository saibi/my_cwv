import SwiftUI

private struct EditTarget: Identifiable {
    let id = UUID()
    let existing: Site?
}

struct SiteListView: View {
    @EnvironmentObject var store: SiteStore
    let onOpen: (Site) -> Void
    @State private var editing: EditTarget?

    private func row(_ site: Site) -> some View {
        Button { onOpen(site) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name).font(.headline)
                Text(site.url.absoluteString).font(.caption).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.defaultPages) { row($0) }  // 기본 사이트: 이동/삭제/편집 없음 (default_page.csv로 관리)
                }
                if !store.userSites.isEmpty {
                    Section("추가한 사이트") {
                        ForEach(store.userSites) { site in
                            row(site)
                                .swipeActions(edge: .trailing) {
                                    Button("삭제", role: .destructive) {
                                        if let i = store.userSites.firstIndex(of: site) { store.remove(at: [i]) }
                                    }
                                    Button("편집") { editing = EditTarget(existing: site) }.tint(.blue)
                                }
                        }
                        .onMove { store.userSites.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { store.remove(at: $0) }
                    }
                }
            }
            .navigationTitle("커뮤니티")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = EditTarget(existing: nil) } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { SiteEditView(existing: $0.existing) }
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
                TextField("이름 (비우면 도메인)", text: $name)
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
        let finalName = n.isEmpty ? (url.host ?? url.absoluteString) : n
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
