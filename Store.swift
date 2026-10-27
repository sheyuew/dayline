import Foundation
struct Entry: Codable, Identifiable { var id = UUID(); var date = Date(); var text: String }
final class LogStore {
 let url: URL
 var items: [Entry] = []
 init(url: URL) { self.url = url; if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode([Entry].self, from: data) { items = saved } }
 func add(_ text: String) throws {
 let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
 guard !clean.isEmpty else { return }
 let next = items + [Entry(text: clean)]
 try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
 try JSONEncoder().encode(next).write(to: url, options: .atomic)
 items = next
 }
 func update(id: UUID, text: String, date: Date) throws {
 let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
 guard !clean.isEmpty else { throw NSError(domain: "Dayline", code: 1, userInfo: [NSLocalizedDescriptionKey: "事项内容不能为空"]) }
 guard let index = items.firstIndex(where: { $0.id == id }) else { throw NSError(domain: "Dayline", code: 2, userInfo: [NSLocalizedDescriptionKey: "找不到该事项"]) }
 var next = items
 next[index].text = clean; next[index].date = date
 next.sort { $0.date < $1.date }
 try JSONEncoder().encode(next).write(to: url, options: .atomic)
 items = next
 }
 func delete(id: UUID) throws {
 let next = items.filter { $0.id != id }
 try JSONEncoder().encode(next).write(to: url, options: .atomic)
 items = next
 }
}
