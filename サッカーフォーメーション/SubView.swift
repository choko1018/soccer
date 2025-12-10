import SwiftUI
import Photos
import LinkPresentation

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

// MARK: - View snapshot helper
final class ViewSnapshotter: ObservableObject {
    weak var hostingView: UIView?

    func snapshot() -> UIImage? {
        guard let view = hostingView else { return nil }
        // レンダラを使用して view を画像化
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
        return renderer.image { ctx in
            // レイヤー描画ではなく drawHierarchy を使って正しく描画
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}

struct SnapshotHosting<Content: View>: UIViewControllerRepresentable {
    let content: Content
    @ObservedObject var snapshotter: ViewSnapshotter

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let vc = UIHostingController(rootView: content)
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        uiViewController.rootView = content
        // 参照を保持（capture 時に使用）
        snapshotter.hostingView = uiViewController.view
    }
}

struct SubView: View {
    // フォーメーションごとの保存ファイル名を受け取る
    var filename: String = "items.json"
    // ナビゲーションバーに表示するタイトル（Formation.name を渡します）
    var title: String? = nil

    @State private var items: [DraggableItem] = []
    @Environment(\.dismiss) var dismiss

    // 追加: 編集モーダル表示用の状態
    @State private var editingIndex: Int? = nil
    @State private var showEditor: Bool = false

    // スクリーンショット用
    @StateObject private var snapshotter = ViewSnapshotter()
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    // 共有フロー用
    @State private var showSharePrompt: Bool = false
    @State private var showActivitySheet: Bool = false
    @State private var shareImage: UIImage? = nil
    // フォーメーションプリセット
    private let formationPresets: [String] = ["初期配置", "4-4-2", "4-3-3", "3-5-2", "test"]
    @State private var selectedPreset: String = "初期配置"

    var body: some View {
        // 全体を VStack にして、ナビゲーションとピッチの間に HStack を挿入
        VStack(spacing: 12) {
            // HStack: プルダウン（Menu）で初期フォーメーションを切り替え
            HStack {
                Menu {
                    ForEach(formationPresets, id: \.self) { preset in
                        Button(action: {
                            selectedPreset = preset
                            applyPreset(preset)
                        }) {
                            Text(preset)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                        Text(selectedPreset)
                        Image(systemName: "chevron.down")
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8
                    )
                }

                Spacer()
            }
            .padding(.horizontal)

            // キャプチャ対象のピッチ表示（SnapshotHosting）
            SnapshotHosting(content:
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
            , snapshotter: snapshotter)
        }
        // title が渡されていればそれを表示
        .navigationBarTitle(Text(title ?? "フォーメーション"), displayMode: .inline)
        .toolbar{
            ToolbarItem(placement: .navigationBarTrailing) {
                // 既存のスクショカメラはそのまま残す
                Button(action: {
                    // キャプチャして写真ライブラリへ保存
                    guard let image = snapshotter.snapshot() else {
                        alertMessage = "画像を取得できませんでした"
                        showAlert = true
                        return
                    }

                    // 保存後に共有するかどうかを確認するため shareImage に保持
                    let handleSavedImage: (Bool, Error?) -> Void = { success, error in
                        DispatchQueue.main.async {
                            if success {
                                // 保存成功: 共有プロンプトを表示
                                shareImage = image
                                showSharePrompt = true
                            } else {
                                alertMessage = "保存に失敗しました: \(error?.localizedDescription ?? "不明なエラー")"
                                showAlert = true
                            }
                        }
                    }

                    // 写真ライブラリ追加の権限を確認して保存
                    if #available(iOS 14, *) {
                        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                            switch status {
                            case .authorized, .limited:
                                PHPhotoLibrary.shared().performChanges({
                                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                                }) { success, error in
                                    handleSavedImage(success, error)
                                }
                            default:
                                DispatchQueue.main.async {
                                    alertMessage = "写真への保存権限が必要です。設定を確認してください。"
                                    showAlert = true
                                }
                            }
                        }
                    } else {
                        PHPhotoLibrary.requestAuthorization { status in
                            if status == .authorized {
                                PHPhotoLibrary.shared().performChanges({
                                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                                }) { success, error in
                                    handleSavedImage(success, error)
                                }
                            } else {
                                DispatchQueue.main.async {
                                    alertMessage = "写真への保存権限が必要です。設定を確認してください。"
                                    showAlert = true
                                }
                            }
                        }
                    }
                }){
                    Image(systemName: "camera")
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("通知"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        // 保存成功後の共有確認ダイアログ
        .alert("保存しました", isPresented: $showSharePrompt) {
            Button("はい") {
                // 共有シートを表示
                showActivitySheet = true
            }
            Button("いいえ", role: .cancel) {
                // 何もしない
            }
        } message: {
            Text("SNSでシェアしますか？")
        }
        // UIActivityViewController を SwiftUI で表示
        .sheet(isPresented: $showActivitySheet, content: {
            if let image = shareImage {
                ActivityView(activityItems: [ImageActivityItemSource(image: image)], isPresented: $showActivitySheet)
                    .onDisappear {
                        // 共有シートが閉じたら shareImage を解放
                        shareImage = nil
                    }
            }
        })
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
                   DraggableItem(position: CGSize(width: 50, height: 50) ),
                   DraggableItem(position: CGSize(width: -50, height: 50) ),
                   DraggableItem(position: CGSize(width: 125, height: 50) ),
                   DraggableItem(position: CGSize(width: -125, height: 50) ),
                   DraggableItem(position: CGSize(width: 125, height: -150) ),
                   DraggableItem(position: CGSize(width: -50, height: -150) ),
                   DraggableItem(position: CGSize(width: -125, height: -150) ),
                   DraggableItem(position: CGSize(width: 50, height: -150) ),
                   DraggableItem(position: CGSize(width: 50, height: -50) ),
                   DraggableItem(position: CGSize(width: -50, height: -50) )
                ]
                // 初回起動時はデフォルトを保存しておく
                Persistence.saveItems(items, filename: filename)
            }

            // items に基づいて selectedPreset を更新
            for preset in formationPresets {
                if matchesPreset(preset) {
                    selectedPreset = preset
                    break
                }
            }
        }
        .onChange(of: items) { oldValue, newValue in
            // items の変更を検知したら新しい値を保存（ファイル名指定）
            Persistence.saveItems(newValue, filename: filename)
        }
    }
}

#Preview {
     SubView(filename: "preview-formation.json", title: "プレビュー")
 }

// プリセットを適用するユーティリティ
extension SubView {
    private func applyPreset(_ preset: String) {
        switch preset {
        case "4-4-2":
            items = [
                DraggableItem(position: CGSize(width: 0, height: 250)),
                DraggableItem(position: CGSize(width: -100, height: 100)),
                DraggableItem(position: CGSize(width: 100, height: 100)),
                DraggableItem(position: CGSize(width: -150, height: 0)),
                DraggableItem(position: CGSize(width: -50, height: 0)),
                DraggableItem(position: CGSize(width: 50, height: 0)),
                DraggableItem(position: CGSize(width: 150, height: 0)),
                DraggableItem(position: CGSize(width: -75, height: -100)),
                DraggableItem(position: CGSize(width: 0, height: -100)),
                DraggableItem(position: CGSize(width: 75, height: -100)),
                DraggableItem(position: CGSize(width: 0, height: -180))
            ]
        case "4-3-3":
            items = [
                DraggableItem(position: CGSize(width: 0, height: 250)),
                DraggableItem(position: CGSize(width: -120, height: 100)),
                DraggableItem(position: CGSize(width: 120, height: 100)),
                DraggableItem(position: CGSize(width: -60, height: 50)),
                DraggableItem(position: CGSize(width: 60, height: 50)),
                DraggableItem(position: CGSize(width: 0, height: 50)),
                DraggableItem(position: CGSize(width: -80, height: -50)),
                DraggableItem(position: CGSize(width: 0, height: -50)),
                DraggableItem(position: CGSize(width: 80, height: -50)),
                DraggableItem(position: CGSize(width: -30, height: -140)),
                DraggableItem(position: CGSize(width: 30, height: -140))
            ]
        case "3-5-2":
            items = [
                DraggableItem(position: CGSize(width: 0, height: 250)),
                DraggableItem(position: CGSize(width: -90, height: 100)),
                DraggableItem(position: CGSize(width: 90, height: 100)),
                DraggableItem(position: CGSize(width: -140, height: 0)),
                DraggableItem(position: CGSize(width: -40, height: 0)),
                DraggableItem(position: CGSize(width: 40, height: 0)),
                DraggableItem(position: CGSize(width: 140, height: 0)),
                DraggableItem(position: CGSize(width: -60, height: -80)),
                DraggableItem(position: CGSize(width: 60, height: -80)),
                DraggableItem(position: CGSize(width: -20, height: -160)),
                DraggableItem(position: CGSize(width: 20, height: -160))
            ]
        case "test":
            items = [
                DraggableItem(position: CGSize(width: 0, height: 250)),
                DraggableItem(position: CGSize(width: -100, height: 100)),
                DraggableItem(position: CGSize(width: 100, height: 100)),
                DraggableItem(position: CGSize(width: -150, height: 0)),
                DraggableItem(position: CGSize(width: -50, height: 0)),
                DraggableItem(position: CGSize(width: 50, height: 0)),
                DraggableItem(position: CGSize(width: 150, height: 0)),
                DraggableItem(position: CGSize(width: -75, height: -100)),
                DraggableItem(position: CGSize(width: 0, height: -100)),
                DraggableItem(position: CGSize(width: 75, height: -100)),
                DraggableItem(position: CGSize(width: 0, height: -180))
            ]
        default:
            // 初期配置（既存のデフォルト）
            items = [
               DraggableItem(position: CGSize(width: 0, height: 250) ),
               DraggableItem(position: CGSize(width: 50, height: 50) ),
               DraggableItem(position: CGSize(width: -50, height: 50) ),
               DraggableItem(position: CGSize(width: 125, height: 50) ),
               DraggableItem(position: CGSize(width: -125, height: 150) ),
               DraggableItem(position: CGSize(width: 125, height: 50) ),
               DraggableItem(position: CGSize(width: -50, height: 50) ),
               DraggableItem(position: CGSize(width: -125, height: 50) ),
               DraggableItem(position: CGSize(width: 50, height: 50) ),
               DraggableItem(position: CGSize(width: 50, height: -50) ),
               DraggableItem(position: CGSize(width: -50, height: -50) )
            ]
        }

        // 選択したプリセットをローカルに保存
        Persistence.saveItems(items, filename: filename)
    }

    // 指定プリセット名に対応する選手位置の配列を返す
    private func presetPositions(for preset: String) -> [CGSize] {
        switch preset {
        case "4-4-2":
            return [
                CGSize(width: 0, height: 250),
                CGSize(width: -100, height: 100),
                CGSize(width: 100, height: 100),
                CGSize(width: -150, height: 0),
                CGSize(width: -50, height: 0),
                CGSize(width: 50, height: 0),
                CGSize(width: 150, height: 0),
                CGSize(width: -75, height: -100),
                CGSize(width: 0, height: -100),
                CGSize(width: 75, height: -100),
                CGSize(width: 0, height: -180)
            ]
        case "4-3-3":
            return [
                CGSize(width: 0, height: 250),
                CGSize(width: -120, height: 100),
                CGSize(width: 120, height: 100),
                CGSize(width: -60, height: 50),
                CGSize(width: 60, height: 50),
                CGSize(width: 0, height: 50),
                CGSize(width: -80, height: -50),
                CGSize(width: 0, height: -50),
                CGSize(width: 80, height: -50),
                CGSize(width: -30, height: -140),
                CGSize(width: 30, height: -140)
            ]
        case "3-5-2":
            return [
                CGSize(width: 0, height: 250),
                CGSize(width: -90, height: 100),
                CGSize(width: 90, height: 100),
                CGSize(width: -140, height: 0),
                CGSize(width: -40, height: 0),
                CGSize(width: 40, height: 0),
                CGSize(width: 140, height: 0),
                CGSize(width: -60, height: -80),
                CGSize(width: 60, height: -80),
                CGSize(width: -20, height: -160),
                CGSize(width: 20, height: -160)
            ]
        default:
            return [
                CGSize(width: 0, height: 250),
                CGSize(width: 50, height: 50),
                CGSize(width: -50, height: 50),
                CGSize(width: 125, height: 50),
                CGSize(width: -125, height: 50),
                CGSize(width: 125, height: -150),
                CGSize(width: -50, height: -150),
                CGSize(width: -125, height: -150),
                CGSize(width: 50, height: -150),
                CGSize(width: 50, height: -50),
                CGSize(width: -50, height: -50)
            ]
        }
    }

    // 現在の items が指定プリセットと概ね一致するかを判定
    private func matchesPreset(_ preset: String) -> Bool {
        let presetPos = presetPositions(for: preset)
        guard presetPos.count == items.count else { return false }
        let tolerance: CGFloat = 8.0 // 位置差の許容範囲
        for (i, pos) in presetPos.enumerated() {
            let current = items[i].position
            if abs(current.width - pos.width) > tolerance || abs(current.height - pos.height) > tolerance {
                return false
            }
        }
        return true
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Binding var isPresented: Bool
    let applicationActivities: [UIActivity]? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        // completion handler で SwiftUI のバインディングを閉じる
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
            DispatchQueue.main.async {
                context.coordinator.isPresented.wrappedValue = false
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    class Coordinator: NSObject {
        var isPresented: Binding<Bool>
        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }
    }
}

final class ImageActivityItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    init(image: UIImage) { self.image = image }

    // プレースホルダとして画像を返す
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }

    // 実際に渡すアイテム（画像）
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
    }

    // メール等で使われる件名
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "フォーメーション画像"
    }

    // サムネイルを共有シート内で表示できるように返す（小さいプレビュー）
    func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
        // suggestedSize に合わせて画像を縮小して返す
        let targetSize = CGSize(width: max(1, size.width), height: max(1, size.height))
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return scaled
    }

    // iOS 13+ のリッチプレビュー用に LPLinkMetadata を返す
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "フォーメーション画像"
        // NSItemProvider を使って画像を渡す
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}
