import SwiftUI

struct NewFormationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FormationsStore

    @State private var name: String = "新しいフォーメーション"

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("フォーメーション名")) {
                    TextField("名前", text: $name)
                }
            }
            .navigationTitle("新規フォーメーション")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        let _ = store.addFormation(name: name)
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
struct NewFormationView_Previews: PreviewProvider {
    static var previews: some View {
        NewFormationView(store: FormationsStore())
    }
}
#endif
