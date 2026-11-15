import SwiftUI

private struct EditTarget: Identifiable {
    let id = UUID()
    let existing: Site?
}

struct SiteListView: View {
    @EnvironmentObject var store: SiteStore
    let onOpen: (Site) -> Void
    @State private var editing: EditTarget?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.sites) { site in
                    Button { onOpen(site) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.name).font(.headline)
                            Text(site.url.absoluteString).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
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
            .overlay { if store.sites.isEmpty { Text("오른쪽 위 +로 사이트를 추가하세요").foregroundStyle(.secondary) } }
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
