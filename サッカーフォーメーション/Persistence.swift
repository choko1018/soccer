import Foundation

/// items（DraggableItem の配列）をアプリのドキュメントディレクトリに JSON で保存・読み込みするヘルパー
/// Image data は Data 型のまま JSON にエンコードされます（base64 表現）。
struct Persistence {
    private static let defaultFilename = "items.json"

    private static func fileURL(for filename: String) -> URL? {
        do {
            let fm = FileManager.default
            let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return docs.appendingPathComponent(filename)
        } catch {
            print("Persistence: ドキュメントディレクトリ取得失敗: \(error)")
            return nil
        }
    }

    // MARK: - ファイル名指定あり API
    static func saveItems(_ items: [DraggableItem], filename: String) {
        guard let url = fileURL(for: filename) else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(items)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Persistence: save failed: \(error)")
        }
    }

    static func loadItems(filename: String) -> [DraggableItem]? {
        guard let url = fileURL(for: filename) else { return nil }
        do {
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let items = try decoder.decode([DraggableItem].self, from: data)
            return items
        } catch {
            print("Persistence: load failed: \(error)")
            return nil
        }
    }

    static func deleteSavedItems(filename: String) {
        guard let url = fileURL(for: filename) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Persistence: delete failed: \(error)")
        }
    }

    // MARK: - 既存互換 API（デフォルトの items.json を使う）
    static func saveItems(_ items: [DraggableItem]) {
        saveItems(items, filename: defaultFilename)
    }

    static func loadItems() -> [DraggableItem]? {
        loadItems(filename: defaultFilename)
    }

    static func deleteSavedItems() {
        deleteSavedItems(filename: defaultFilename)
    }
}
