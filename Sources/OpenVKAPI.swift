import Foundation

enum APIError: LocalizedError {
    case msg(String)
    var errorDescription: String? { if case .msg(let m) = self { return m }; return nil }
}

// Формат запросов взят по аналогии с VK API (/token и /method/audio.get).
// Если OpenVK отдаёт другие поля, поправь разбор в audios().
struct OpenVKAPI {
    let base: URL
    let token: String

    static func login(base: URL, user: String, pass: String) async throws -> String {
        var c = URLComponents(url: base.appendingPathComponent("token"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "username", value: user),
                        .init(name: "password", value: pass),
                        .init(name: "grant_type", value: "password")]
        let (d, _) = try await URLSession.shared.data(from: c.url!)
        let j = try JSONSerialization.jsonObject(with: d) as? [String: Any]
        if let t = j?["access_token"] as? String { return t }
        throw APIError.msg((j?["error_description"] as? String) ?? "Сервер не выдал токен")
    }

    func audios() async throws -> [Track] {
        var c = URLComponents(url: base.appendingPathComponent("method/audio.get"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "access_token", value: token),
                        .init(name: "v", value: "5.126"),
                        .init(name: "count", value: "1000")]
        let (d, _) = try await URLSession.shared.data(from: c.url!)
        guard let j = try JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            throw APIError.msg("Неверный ответ сервера")
        }
        guard let items = (j["response"] as? [String: Any])?["items"] as? [[String: Any]] else {
            throw APIError.msg(((j["error"] as? [String: Any])?["error_msg"] as? String) ?? "Нет данных")
        }
        return items.compactMap { a in
            guard let s = a["url"] as? String, let u = URL(string: s) else { return nil }
            let owner = a["owner_id"] as? Int ?? 0
            let aid = a["id"] as? Int ?? 0
            let album = (a["album"] as? [String: Any])?["title"] as? String
            return Track(id: "\(owner)_\(aid)",
                         title: a["title"] as? String ?? "Без названия",
                         artist: a["artist"] as? String ?? "Неизвестный исполнитель",
                         duration: a["duration"] as? Int ?? 0,
                         album: album ?? "Все аудио",
                         genre: "Без жанра",
                         url: u)
        }
    }
}
