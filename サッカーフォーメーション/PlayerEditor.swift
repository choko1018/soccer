import SwiftUI
import PhotosUI

struct PlayerEditor: View {
    @Binding var item: DraggableItem
    @Binding var isPresented: Bool

    @State private var pickerItem: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // プレビュー
                if let data = item.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                }

                // 画像選択ボタン
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Text("画像を選択")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(8)
                }
                .onChange(of: pickerItem) { newItem in
                    Task {
                        if let newItem {
                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                // 取得したデータをバインディングに保存
                                await MainActor.run {
                                    item.imageData = data
                                }
                            }
                        }
                    }
                }

                // 名前編集
                TextField("名前", text: $item.name)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("選手を編集")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#if DEBUG
struct PlayerEditor_Previews: PreviewProvider {
    @State static var item = DraggableItem(position: .zero)
    @State static var presented = true
    static var previews: some View {
        PlayerEditor(item: $item, isPresented: $presented)
    }
}
#endif
