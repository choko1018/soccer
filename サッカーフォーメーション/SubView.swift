import SwiftUI

struct DraggableItem: Identifiable, Codable, Equatable {
    let id: UUID
    var position: CGSize
    var name: String = "あああ"
    var imageData: Data? = nil // 追加: 選手画像を保持

    // Codable にするためにカスタム実装（CGSize は直接 Codable で扱わない）
    enum CodingKeys: String, CodingKey {
        case id
        case positionWidth
        case positionHeight
        case name
        case imageData
    }

    init(id: UUID = UUID(), position: CGSize, name: String = "あああ", imageData: Data? = nil) {
        self.id = id
        self.position = position
        self.name = name
        self.imageData = imageData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let width = try container.decode(CGFloat.self, forKey: .positionWidth)
        let height = try container.decode(CGFloat.self, forKey: .positionHeight)
        let name = try container.decode(String.self, forKey: .name)
        let imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        self.id = id
        self.position = CGSize(width: width, height: height)
        self.name = name
        self.imageData = imageData
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(position.width, forKey: .positionWidth)
        try container.encode(position.height, forKey: .positionHeight)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(imageData, forKey: .imageData)
    }
}

struct SubView: View {
    // フォーメーションごとの保存ファイル名を受け取る
    var filename: String = "items.json"

    @State private var items: [DraggableItem] = []
    @Environment(\.dismiss) var dismiss

    // 追加: 編集モーダル表示用の状態
    @State private var editingIndex: Int? = nil
    @State private var showEditor: Bool = false

    var body: some View {
        ZStack {
            Image("ピッチ")
             .resizable()
             .frame(width: 450, height: 650, alignment: .bottom)
            ForEach(items.indices, id: \.self) { index in
                SoccerPleyer(
                    position: $items[index].position,
                    name: $items[index].name,
                    imageData: $items[index].imageData
                )
                .onTapGesture {
                    // タップで編集モーダルを表示
                    editingIndex = index
                    showEditor = true
                }
            }
        }
        .navigationBarTitle(Text("フォーメーション一覧"), displayMode: .inline)
        .toolbar{
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                }){
                    Image(systemName: "camera")
                }
            }
        }
        // 編集用シート（下から出る見た目は presentationDetents を使えます）
        .sheet(isPresented: $showEditor) {
            if let i = editingIndex {
                PlayerEditor(item: $items[i], isPresented: $showEditor)
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            // 保存されている items を読み込む（ファイル名指定）
            if let saved = Persistence.loadItems(filename: filename) {
                items = saved
            } else {
                // 保存がない場合は既存のデフォルト配置を初期化
                items = [
                   DraggableItem(position: CGSize(width: 0, height: 250) ),
                   DraggableItem(position: CGSize(width: 50, height: 150) ),
                   DraggableItem(position: CGSize(width: -50, height: 150) ),
                   DraggableItem(position: CGSize(width: 125, height: 150) ),
                   DraggableItem(position: CGSize(width: -125, height: 150) ),
                   DraggableItem(position: CGSize(width: 125, height: 50) ),
                   DraggableItem(position: CGSize(width: -50, height: 50) ),
                   DraggableItem(position: CGSize(width: -125, height: 50) ),
                   DraggableItem(position: CGSize(width: 50, height: 50) ),
                   DraggableItem(position: CGSize(width: 50, height: -50) ),
                   DraggableItem(position: CGSize(width: -50, height: -50) )
                ]
                // 初回起動時はデフォルトを保存しておく
                Persistence.saveItems(items, filename: filename)
            }
        }
        .onChange(of: items) { oldValue, newValue in
            // items の変更を検知したら新しい値を保存（ファイル名指定）
            Persistence.saveItems(newValue, filename: filename)
        }
    }
}

#Preview {
    SubView(filename: "preview-formation.json")
}
