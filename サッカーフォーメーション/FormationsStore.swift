import Foundation
import SwiftUI

struct Formation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var filename: String

    init(id: UUID = UUID(), name: String, filename: String) {
        self.id = id
        self.name = name
        self.filename = filename
    }
}

final class FormationsStore: ObservableObject {
    @Published var formations: [Formation] = []

    private let filename = "formations.json"

    init() {
        load()
    }

    private func fileURL() -> URL? {
        do {
            let fm = FileManager.default
            let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return docs.appendingPathComponent(filename)
        } catch {
            print("FormationsStore: ドキュメントディレクトリ取得失敗: \(error)")
            return nil
        }
    }

    func load() {
        guard let url = fileURL() else { return }
        do {
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else {
                formations = []
                return
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            formations = try decoder.decode([Formation].self, from: data)
        } catch {
            print("FormationsStore: load failed: \(error)")
            formations = []
        }
    }

    func save() {
        guard let url = fileURL() else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(formations)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("FormationsStore: save failed: \(error)")
        }
    }

    func addFormation(name: String) -> Formation {
        // ユニークなファイル名を生成
        let filename = "formation-\(UUID().uuidString).json"
        let formation = Formation(name: name, filename: filename)
        formations.append(formation)
        save()

        // 新規作成時にデフォルトの items を保存しておく
        let defaultItems: [DraggableItem] = [
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
        Persistence.saveItems(defaultItems, filename: filename)
        return formation
    }

    func removeFormation(at offsets: IndexSet) {
        for index in offsets {
            let f = formations[index]
            // 形成ファイルも削除
            Persistence.deleteSavedItems(filename: f.filename)
        }
        formations.remove(atOffsets: offsets)
        save()
    }

    func renameFormation(id: UUID, newName: String) {
        guard let idx = formations.firstIndex(where: { $0.id == id }) else { return }
        formations[idx].name = newName
        save()
    }
}
