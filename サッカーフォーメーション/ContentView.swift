import SwiftUI

struct ContentView: View {
    @StateObject private var store = FormationsStore()
    @State private var showingNew = false

    var body: some View {
        NavigationView {
            List {
                if store.formations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("まだフォーメーションはありません")
                            .font(.headline)
                        Text("右上の + ボタンで新しいフォーメーションを作成できます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                } else {
                    ForEach(store.formations) { formation in
                        NavigationLink(destination: SubView(filename: formation.filename)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(formation.name)
                                        .font(.headline)
                                    Text(formation.filename)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .onDelete { offsets in
                        store.removeFormation(at: offsets)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("フォーメーション一覧")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "lightbulb.min.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button(action: {}) {
                            Image(systemName: "bell.badge.fill")
                        }
                        Button {
                            showingNew = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNew) {
                NewFormationView(store: store)
            }
        }
    }
}

#Preview {
    ContentView()
}
