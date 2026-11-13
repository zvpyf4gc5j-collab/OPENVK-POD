import Foundation

struct Track: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let duration: Int
    let album: String
    let genre: String
    let url: URL
    var label: String { "\(artist) — \(title)" }
}

func mm(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
