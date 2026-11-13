import SwiftUI

struct Pal {
    let bg, r1, r2, text, sub, bar: Color
    static let light = Pal(bg: hex(0xf6f6f6), r1: .white, r2: hex(0xe9e9e9), text: .black, sub: hex(0x777777), bar: hex(0xe6e6e6))
    static let dark = Pal(bg: hex(0x1b1b1d), r1: hex(0x232325), r2: hex(0x2c2c2e), text: hex(0xf0f0f0), sub: hex(0xaaaaaa), bar: hex(0x333335))
}

struct PodView: View {
    @EnvironmentObject var pod: Pod

    var body: some View {
        GeometryReader { g in
            let w = min(g.size.width, g.size.height * 1170 / 2532)
            let u = w / 100
            ZStack {
                Color.black.ignoresSafeArea()
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6 * u)
                        .fill(LinearGradient(colors: bodyPresets[pod.bodyIdx].1, startPoint: .top, endPoint: .bottom))
                    ScreenView(u: u)
                        .frame(width: 91.5 * u, height: 103.4 * u)
                        .clipShape(RoundedRectangle(cornerRadius: 2.4 * u))
                        .overlay(RoundedRectangle(cornerRadius: 2.4 * u).stroke(Color(white: 0.18), lineWidth: 1.2 * u))
                        .offset(x: 4.2 * u, y: 12.1 * u)
                    ClickWheel(u: u)
                        .frame(width: 70 * u, height: 70 * u)
                        .offset(x: 15 * u, y: 130.8 * u)
                }
                .frame(width: w, height: w * 2532 / 1170)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $pod.showLogin) { LoginSheet() }
    }
}

struct ScreenView: View {
    @EnvironmentObject var pod: Pod
    @EnvironmentObject var player: Player
    let u: CGFloat

    var body: some View {
        let pal = pod.dark ? Pal.dark : Pal.light
        let f = pod.top
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Text(f.kind.title)
                    Spacer()
                    Image(systemName: "speaker.fill")
                    Image(systemName: player.isPlaying ? "play.fill" : "pause.fill")
                    Image(systemName: "battery.50")
                }.padding(.horizontal, 2.4 * u)
                Text(Date(), style: .time)
            }
            .imageScale(.small)
            .font(.system(size: 3.9 * u, weight: .medium))
            .foregroundColor(pal.text)
            .frame(height: 5.4 * u)
            .background(pal.bar)

            if f.kind == .nowPlaying { NowPlaying(u: u, pal: pal) } else { ListBody(u: u, pal: pal, frame: f) }
        }
        .background(pal.bg)
    }
}

struct ListBody: View {
    @EnvironmentObject var pod: Pod
    let u: CGFloat
    let pal: Pal
    let frame: Frame

    var body: some View {
        let items = pod.items(frame.kind)
        let n = items.count
        let start = max(0, min(frame.sel - 3, n - 7))
        let end = min(n, start + 7)
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(start..<max(start, end)), id: \.self) { i in row(items[i], i, i == frame.sel) }
                Spacer(minLength: 0)
            }
            .frame(width: frame.kind.full ? nil : 44.6 * u)
            if !frame.kind.full {
                ZStack {
                    LinearGradient(colors: [hex(0xd9d9d9), hex(0xf7f7f7)], startPoint: .leading, endPoint: UnitPoint(x: 0.12, y: 0.5))
                    Image(systemName: "music.note").font(.system(size: 13 * u)).foregroundColor(Color(white: 0.45))
                }
            }
        }
    }

    func row(_ it: Item, _ i: Int, _ sel: Bool) -> some View {
        HStack {
            Text(it.label).lineLimit(1)
            Spacer(minLength: 2)
            if let v = it.value {
                Text(v).font(.system(size: 3.9 * u, weight: .regular)).opacity(0.75)
            } else if it.chevron {
                Image(systemName: "chevron.right").font(.system(size: 4 * u, weight: .bold)).opacity(sel ? 1 : 0.3)
            }
        }
        .font(.system(size: 5.3 * u, weight: .bold))
        .padding(.horizontal, 3.4 * u)
        .frame(maxWidth: .infinity)
        .frame(height: 12.3 * u)
        .foregroundColor(sel ? .white : pal.text)
        .background(sel ? AnyView(LinearGradient(colors: [hex(0x4b9be8), hex(0x2a5f9e)], startPoint: .top, endPoint: .bottom))
                        : AnyView(i % 2 == 1 ? pal.r2 : pal.r1))
    }
}

struct NowPlaying: View {
    @EnvironmentObject var pod: Pod
    @EnvironmentObject var player: Player
    let u: CGFloat
    let pal: Pal

    var cover: some View {
        ZStack {
            Rectangle().fill(Color(white: 0.78))
            Image(systemName: "music.note").font(.system(size: 11 * u)).foregroundColor(Color(white: 0.42))
        }.frame(width: 38 * u, height: 40 * u)
    }

    var body: some View {
        if let t = player.current {
            let idx = (player.queue.firstIndex(of: t) ?? 0) + 1
            VStack(spacing: 0) {
                HStack(spacing: 6.5 * u) {
                    Spacer()
                    Image(systemName: "shuffle").opacity(player.shuffle ? 1 : 0.3)
                    Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat").opacity(player.repeatMode == .off ? 0.3 : 1)
                }
                .font(.system(size: 4.2 * u, weight: .semibold)).foregroundColor(pal.sub)
                .padding(.horizontal, 5 * u).padding(.top, 5.5 * u)

                HStack(alignment: .top, spacing: 5.5 * u) {
                    VStack(spacing: 0) {
                        cover.rotation3DEffect(.degrees(-15), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
                        cover.scaleEffect(y: -1)
                            .frame(width: 38 * u, height: 28 * u, alignment: .top).clipped()
                            .mask(LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    }
                    VStack(alignment: .leading, spacing: 1.2 * u) {
                        Text(t.title).font(.system(size: 5.6 * u, weight: .black)).foregroundColor(pal.text).lineLimit(1)
                        Text(t.artist).lineLimit(1)
                        Text(t.album).lineLimit(1)
                        Text("\(idx) / \(player.queue.count)").padding(.top, 4 * u)
                    }
                    .font(.system(size: 4.8 * u, weight: .semibold)).foregroundColor(pal.sub)
                    .padding(.top, 26 * u)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 4.9 * u).padding(.top, 8 * u)

                Spacer(minLength: 0)
                controls(t).frame(height: 7.4 * u).padding(.horizontal, 4.5 * u)
                HStack(spacing: 6.4 * u) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle().fill(i == pod.mode ? Color(white: 0.4) : Color(white: 0.8)).frame(width: 1.6 * u, height: 1.6 * u)
                    }
                }.padding(.vertical, 2.3 * u)
            }
        } else {
            Text("Ничего не выбрано").foregroundColor(pal.sub).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder func controls(_ t: Track) -> some View {
        switch pod.mode {
        case 0:
            HStack(spacing: 2.5 * u) {
                Text(mm(Int(player.position))).frame(width: 9 * u, alignment: .leading)
                bar(player.position / Double(max(t.duration, 1)))
                Text("-" + mm(max(0, t.duration - Int(player.position)))).frame(width: 10 * u, alignment: .trailing)
            }.font(.system(size: 4 * u)).foregroundColor(pal.text)
        case 1:
            HStack(spacing: 2.5 * u) {
                Image(systemName: "speaker.fill")
                bar(player.volume)
                Image(systemName: "speaker.wave.3.fill")
            }.font(.system(size: 4 * u)).foregroundColor(pal.sub)
        case 2:
            HStack(spacing: 2.5 * u) {
                Image(systemName: "shuffle")
                seg(["Off", "On"], player.shuffle ? 1 : 0)
            }.font(.system(size: 4 * u)).foregroundColor(pal.sub)
        default:
            HStack(spacing: 2.5 * u) {
                Image(systemName: "repeat")
                seg(["Off", "All", "1"], player.repeatMode == .off ? 0 : (player.repeatMode == .all ? 1 : 2))
            }.font(.system(size: 4 * u)).foregroundColor(pal.sub)
        }
    }

    func bar(_ p: Double) -> some View {
        let q = CGFloat(min(1, max(0, p)))
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.82)).frame(height: u)
                Capsule().fill(Color(white: 0.42)).frame(width: g.size.width * q, height: u)
                Circle().fill(Color.black).frame(width: 3.2 * u, height: 3.2 * u).offset(x: g.size.width * q - 1.6 * u)
            }.frame(maxHeight: .infinity)
        }.frame(height: 3.2 * u)
    }

    func seg(_ opts: [String], _ sel: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(opts.indices), id: \.self) { i in
                Text(opts[i]).font(.system(size: 4.6 * u, weight: .heavy))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(i == sel ? Color(red: 0.04, green: 0.52, blue: 1) : Color(white: 0.47))
                    .background(i == sel ? Color.white : Color.clear)
                    .cornerRadius(1.4 * u)
            }
        }
        .padding(0.5 * u).background(Color(white: 0.82)).cornerRadius(1.8 * u).frame(height: 7.2 * u)
    }
}

struct LoginSheet: View {
    @EnvironmentObject var pod: Pod
    @EnvironmentObject var player: Player
    @State private var server = "https://ovk.to"
    @State private var user = ""
    @State private var pass = ""
    @State private var token = ""
    @State private var msg = ""
    @State private var busy = false

    var body: some View {
        NavigationView {
            Form {
                Section("Сервер") {
                    TextField("https://ovk.to", text: $server).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Вход") {
                    TextField("Логин", text: $user).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Пароль", text: $pass)
                }
                Section("Или токен вместо логина и пароля") {
                    TextField("Токен доступа", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Button(busy ? "Загрузка..." : "Войти") {
                        Task { @MainActor in
                            busy = true
                            let r = await player.connect(base: server, user: user, pass: pass, token: token)
                            busy = false
                            msg = r ?? "Готово"
                            if r == nil { pod.showLogin = false }
                        }
                    }.disabled(busy)
                    if !msg.isEmpty { Text(msg).font(.footnote) }
                }
            }
            .navigationTitle("OpenVK")
        }
    }
}
