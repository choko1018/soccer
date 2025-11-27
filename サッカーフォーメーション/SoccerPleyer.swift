import SwiftUI
import UIKit

struct SoccerPleyer: View {
    @Binding var position: CGSize
    @Binding var name: String
    @Binding var imageData: Data?
    @State private var lastPosition: CGSize = .zero
    var body: some View {
        VStack{
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50, )
                    .foregroundColor(.white)
            }
            Text("\(name)")
                .foregroundColor(.white)
        }
        .offset(x: position.width, y: position.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // ドラッグの移動量を現在位置に加算して更新
                    position = CGSize(width: lastPosition.width + value.translation.width,
                                      height: lastPosition.height + value.translation.height)
                }
                .onEnded { _ in
                    // ドラッグ終了時に最後の位置を保存
                    lastPosition = position
                }
        )
        .onAppear {
            // 初回表示時にバインディングの現在値を lastPosition に同期
            lastPosition = position
        }
    }
}
