import SwiftUI

struct ContentView: View {
    @StateObject private var store = FormationsStore()
    // シート制御用（どのシートを表示するか）
    enum ActiveSheet: Identifiable {
        case new
        case edit

        var id: Int {
            switch self {
            case .new: return 0
            case .edit: return 1
            }
        }
    }

    @State private var activeSheet: ActiveSheet? = nil

    // 編集用の状態
    @State private var editingFormationID: UUID? = nil
    @State private var editingName: String = ""

    // 日付表示用のフォーマッタを静的に用意
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        // 年/月/日 と 時刻 を表示 (例: 2025/12/03 14:30)
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
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
                        // formation.name を title として渡す
                        NavigationLink(destination: SubView(filename: formation.filename, title: formation.name)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(formation.name)
                                        .font(.headline)
                                    // createdAt (Date) をフォーマットして表示
                                    Text(Self.dateFormatter.string(from: formation.createdAt))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                // 右スワイプアクションで操作するため、固定の chevron は省略
                            }
                            .padding(.vertical, 8)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // 削除ボタン
                            Button(role: .destructive) {
                                if let idx = store.formations.firstIndex(where: { $0.id == formation.id }) {
                                    store.removeFormation(at: IndexSet(integer: idx))
                                }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }

                            // 編集ボタン
                            Button {
                                // 編集用の状態をセットしてシート表示
                                editingFormationID = formation.id
                                editingName = formation.name
                                activeSheet = .edit
                            } label: {
                                Label("編集", systemImage: "pencil")
                            }
                            .tint(.blue)
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
                // 単一の ToolbarItem を使って安定させる（押下時にログも出す）
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // デバッグ用ログ。タップを確かめるためにコンソール出力します。
                        print("[ContentView] plus tapped")
                        activeSheet = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新規作成")
                }
             }
            // 1つの sheet(item:) で New / Edit を切り替える
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .new:
                    NewFormationView(store: store)
                case .edit:
                    NavigationView {
                        VStack(spacing: 16) {
                            Text("フォーメーション名を編集")
                                .font(.headline)
                            TextField("フォーメーション名", text: $editingName)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            Spacer()
                        }
                        .padding(.top)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("キャンセル") {
                                    activeSheet = nil
                                    editingFormationID = nil
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("保存") {
                                    if let id = editingFormationID, !editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        store.renameFormation(id: id, newName: editingName)
                                    }
                                    activeSheet = nil
                                    editingFormationID = nil
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
