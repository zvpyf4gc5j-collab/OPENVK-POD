import SwiftUI
import UIKit
import AudioToolbox
import Combine

func hex(_ v: UInt32) -> Color {
    Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
}

let bodyPresets: [(String, [Color])] = [
    ("Серебро", [hex(0xbdbdbd), hex(0xd2d2d2), hex(0xa9a9a9), hex(0x6f6f6f)]),
    ("Виноград", [hex(0x8b6fb0), hex(0xa58bc9), hex(0x7a5c9e), hex(0x4e3a69)]),
    ("Небо", [hex(0x8fc3e8), hex(0xaad4f0), hex(0x7fb2d8), hex(0x4f7fa3)]),
    ("Цитрус", [hex(0xf0c14b), hex(0xf6d77a), hex(0xe0aa30), hex(0xa97c1a)]),
    ("Румяна", [hex(0xf0b6c0), hex(0xf6cdd4), hex(0xe2a0ac), hex(0xb06c7a)]),
    ("Графит", [hex(0x4a4a4c), hex(0x2e2e30), hex(0x222222), hex(0x101010)])
]
let wheelPresets: [(String, Color, Color)] = [
    ("Белое", .white, hex(0x6a6a6a)),
    ("Чёрное", hex(0x222222), hex(0xbbbbbb)),
    ("Серое", hex(0xcfcfd2), hex(0x555555))
]

enum Kind: Hashable {
    case main, playlists, artists, albums, genres, songs, settings, nowPlaying
    case list(String, [String])

    var title: String {
        switch self {
        case .main: return "Меню"
        case .playlists: return "Плейлисты"
        case .artists: return "Исполнители"
        case .albums: return "Альбомы"
        case .genres: return "Жанры"
        case .songs: return "Песни"
        case .settings: return "Настройки"
        case .nowPlaying: return "Сейчас играет"
        case .list(let t, _): return t
        }
    }
    var full: Bool {
        switch self {
        case .songs, .settings, .list: return true
        default: return false
        }
    }
}

struct Frame { var kind: Kind; var sel: Int }
struct Item {
    var label: String
    var value: String? = nil
    var chevron = true
    var action: () -> Void
}

final class Pod: ObservableObject {
    let player: Player
    @Published var stack = [Frame(kind: .main, sel: 3)]
    @Published var mode = 0
    @Published var showLogin = false
    @Published var dark: Bool { didSet { UserDefaults.standard.set(dark, forKey: "dark") } }
    @Published var bodyIdx: Int { didSet { UserDefaults.standard.set(bodyIdx, forKey: "body") } }
    @Published var wheelIdx: Int { didSet { UserDefaults.standard.set(wheelIdx, forKey: "wheel") } }
    @Published var hap: Int { didSet { UserDefaults.standard.set(hap, forKey: "hap") } }
    @Published var sort: Int { didSet { UserDefaults.standard.set(sort, forKey: "sort") } }
    private var cancel: AnyCancellable?

    init(player: Player) {
        self.player = player
        let d = UserDefaults.standard
        dark = d.bool(forKey: "dark")
        bodyIdx = d.integer(forKey: "body")
        wheelIdx = d.integer(forKey: "wheel")
        hap = d.object(forKey: "hap") as? Int ?? 1
        sort = d.integer(forKey: "sort")
        cancel = player.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var top: Frame { stack[stack.count - 1] }

    func sortedTracks() -> [Track] {
        switch sort {
        case 1: return player.tracks.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case 2: return player.tracks.sorted { $0.artist.localizedCompare($1.artist) == .orderedAscending }
        default: return player.tracks
        }
    }

    func items(_ k: Kind) -> [Item] {
        let ts = player.tracks
        func uniq(_ f: (Track) -> String) -> [String] {
            var seen = Set<String>()
            return ts.map(f).filter { seen.insert($0).inserted }
        }
        func nav(_ l: String, _ k: Kind) -> Item { Item(label: l) { self.push(k) } }
        func trackItem(_ t: Track, _ q: [Track]) -> Item {
            Item(label: t.label, chevron: false) { self.player.play(t, queue: q); self.push(.nowPlaying) }
        }
        switch k {
        case .main:
            return [nav("Плейлисты", .playlists), nav("Исполнители", .artists), nav("Альбомы", .albums),
                    nav("Песни", .songs), nav("Жанры", .genres), nav("Настройки", .settings),
                    Item(label: "Перемешать...", chevron: false) { self.shuffleAll() },
                    nav("Сейчас играет", .nowPlaying)]
        case .playlists:
            return [nav("Мои аудио", .list("Мои аудио", ts.map { $0.id }))]
        case .artists:
            return uniq { $0.artist }.map { a in nav(a, .list(a, ts.filter { $0.artist == a }.map { $0.id })) }
        case .albums:
            return uniq { $0.album }.map { a in nav(a, .list(a, ts.filter { $0.album == a }.map { $0.id })) }
        case .genres:
            return uniq { $0.genre }.map { g in nav(g, .list(g, ts.filter { $0.genre == g }.map { $0.id })) }
        case .songs:
            let q = sortedTracks()
            return q.map { trackItem($0, q) }
        case .list(_, let ids):
            let q = ids.compactMap { id in ts.first { $0.id == id } }
            return q.map { trackItem($0, q) }
        case .settings:
            return [
                Item(label: "Тема экрана", value: dark ? "Тёмная" : "Светлая", chevron: false) { self.dark.toggle() },
                Item(label: "Цвет корпуса", value: bodyPresets[bodyIdx].0, chevron: false) { self.bodyIdx = (self.bodyIdx + 1) % bodyPresets.count },
                Item(label: "Цвет колеса", value: wheelPresets[wheelIdx].0, chevron: false) { self.wheelIdx = (self.wheelIdx + 1) % wheelPresets.count },
                Item(label: "Сортировка песен", value: ["Как в OpenVK", "Название", "Исполнитель"][sort], chevron: false) { self.sort = (self.sort + 1) % 3 },
                Item(label: "Вибрация", value: ["Выкл", "Слабая", "Сильная"][hap], chevron: false) { self.hap = (self.hap + 1) % 3 },
                Item(label: "OpenVK", value: player.account ? "Подключено" : "Войти", chevron: false) { self.showLogin = true }
            ]
        case .nowPlaying:
            return []
        }
    }

    func push(_ k: Kind) {
        stack.append(Frame(kind: k, sel: 0))
        if k == .nowPlaying { mode = 0 }
    }
    func back() { if stack.count > 1 { stack.removeLast() } }

    func shuffleAll() {
        guard let t = player.tracks.randomElement() else { return }
        player.shuffle = true
        player.play(t, queue: player.tracks)
        push(.nowPlaying)
    }

    func step(_ d: Int) {
        if top.kind == .nowPlaying {
            switch mode {
            case 0: player.seekBy(Double(d) * 5)
            case 1: player.setVolume(player.volume + Double(d) * 0.05)
            case 2: player.shuffle = d > 0
            default:
                let o: [Repeat] = [.off, .all, .one]
                let i = max(0, min(2, (o.firstIndex(of: player.repeatMode) ?? 0) + d))
                player.repeatMode = o[i]
            }
        } else {
            let n = items(top.kind).count
            var f = top
            f.sel = max(0, min(n - 1, f.sel + d))
            stack[stack.count - 1] = f
        }
    }

    func select() {
        if top.kind == .nowPlaying { mode = (mode + 1) % 4; return }
        let it = items(top.kind)
        if top.sel < it.count { it[top.sel].action() }
    }

    func haptic() {
        if hap > 0 { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: hap == 1 ? 0.4 : 1.0) }
        AudioServicesPlaySystemSound(1104)
    }
}
