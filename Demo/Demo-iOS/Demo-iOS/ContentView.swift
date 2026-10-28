// FILE: Demo/Demo-iOS/Demo-iOS/ContentView.swift
import SwiftUI
import UniformTypeIdentifiers
import Libmpv
import QuartzCore

// MARK: - Track model + mpv helpers (gộp vào đây để chỉ sửa 1 file)

struct MPVTrack: Identifiable, Hashable {
    let id: Int          // track id mpv, dùng cho sid / aid
    let title: String
    let lang: String
    let codec: String
    let selected: Bool

    var displayName: String {
        var parts: [String] = []
        if !lang.isEmpty { parts.append(lang.uppercased()) }
        if !title.isEmpty { parts.append(title) }
        if !codec.isEmpty { parts.append("(\(codec))") }
        let name = parts.isEmpty ? "Track \(id)" : parts.joined(separator: " ")
        return selected ? "✓ \(name)" : name
    }
}

extension MPVMetalViewController {
    private func mpvString(_ name: String) -> String {
        guard let mpv = mpv, let cstr = mpv_get_property_string(mpv, name) else { return "" }
        defer { mpv_free(cstr) }
        return String(cString: cstr)
    }

    /// type: "sub" hoặc "audio"
    func tracks(type: String) -> [MPVTrack] {
        guard let mpv = mpv else { return [] }
        var count: Int64 = 0
        mpv_get_property(mpv, "track-list/count", MPV_FORMAT_INT64, &count)

        var result: [MPVTrack] = []
        for i in 0..<Int(count) {
            guard mpvString("track-list/\(i)/type") == type else { continue }
            result.append(MPVTrack(
                id: Int(mpvString("track-list/\(i)/id")) ?? 0,
                title: mpvString("track-list/\(i)/title"),
                lang: mpvString("track-list/\(i)/lang"),
                codec: mpvString("track-list/\(i)/codec"),
                selected: mpvString("track-list/\(i)/selected") == "yes"
            ))
        }
        return result
    }

    // MARK: Ghi nhớ lựa chọn audio / sub (lưu trong bộ nhớ app, mỗi người dùng một máy)

    private enum PrefKey {
        static let audioLang = "pref.audio.lang"
        static let audioTitle = "pref.audio.title"
        static let subLang = "pref.sub.lang"       // giá trị subOff nghĩa là người dùng đã tắt sub
        static let subTitle = "pref.sub.title"
        static let subOff = "__off__"
    }

    /// track = nil -> tắt subtitle. Lựa chọn được lưu lại để dùng cho các video sau.
    func selectSubtitle(_ track: MPVTrack?) {
        guard let mpv = mpv else { return }
        mpv_set_property_string(mpv, "sid", track.map { String($0.id) } ?? "no")

        let d = UserDefaults.standard
        if let track {
            if track.lang.isEmpty {
                // Track không có mã ngôn ngữ thì không thể ghi nhớ
                d.removeObject(forKey: PrefKey.subLang)
                d.removeObject(forKey: PrefKey.subTitle)
            } else {
                d.set(track.lang, forKey: PrefKey.subLang)
                d.set(track.title, forKey: PrefKey.subTitle)
            }
        } else {
            d.set(PrefKey.subOff, forKey: PrefKey.subLang)
            d.removeObject(forKey: PrefKey.subTitle)
        }
    }

    /// Chọn audio và ghi nhớ lựa chọn cho các video sau.
    func selectAudio(_ track: MPVTrack) {
        guard let mpv = mpv else { return }
        mpv_set_property_string(mpv, "aid", String(track.id))

        let d = UserDefaults.standard
        if track.lang.isEmpty {
            d.removeObject(forKey: PrefKey.audioLang)
            d.removeObject(forKey: PrefKey.audioTitle)
        } else {
            d.set(track.lang, forKey: PrefKey.audioLang)
            d.set(track.title, forKey: PrefKey.audioTitle)
        }
    }

    /// Đưa mã ngôn ngữ 2 chữ (en) và 3 chữ (eng) về cùng một dạng để so sánh được với nhau.
    /// Mã lạ (ví dụ "enm" của English honorifics) được giữ nguyên, nên vẫn tách biệt với "en".
    fileprivate static func normalizedLang(_ code: String) -> String {
        let c = code.lowercased().split(separator: "-").first.map(String.init) ?? ""
        let groups: [[String]] = [
            ["en", "eng"], ["ja", "jpn"], ["zh", "zho", "chi"], ["ko", "kor"], ["es", "spa"],
            ["fr", "fra", "fre"], ["de", "deu", "ger"], ["it", "ita"], ["pt", "por"], ["ru", "rus"],
            ["vi", "vie"], ["th", "tha"], ["id", "ind"], ["ar", "ara"], ["hi", "hin"],
            ["tr", "tur"], ["pl", "pol"], ["nl", "nld", "dut"]
        ]
        return groups.first(where: { $0.contains(c) })?.first ?? c
    }

    /// Gọi mỗi khi một video vừa mở xong: áp lại audio / sub mà người dùng đã chọn lần trước.
    /// Ưu tiên track đúng cả ngôn ngữ lẫn tên; không có thì lấy track cùng ngôn ngữ;
    /// không có nữa thì để nguyên lựa chọn mặc định của mpv.
    func applySavedTrackPreferences() {
        guard let mpv = mpv else { return }
        let d = UserDefaults.standard

        func pick(_ list: [MPVTrack], lang: String, title: String?) -> MPVTrack? {
            let wanted = MPVMetalViewController.normalizedLang(lang)
            let sameLang = list.filter { MPVMetalViewController.normalizedLang($0.lang) == wanted }

            // 1. Track trùng cả tên với lần chọn trước (ví dụ "Full" hoặc "Signs/Songs")
            if let title, !title.isEmpty, let exact = sameLang.first(where: { $0.title == title }) {
                return exact
            }
            // 2. mpv đã tự chọn sẵn một track cùng ngôn ngữ (thường là track mặc định của file): giữ nguyên
            if let current = sameLang.first(where: { $0.selected }) { return current }
            // 3. Tránh track phụ (Signs / Songs / Forced) nếu còn track khác cùng ngôn ngữ
            let extras = ["sign", "song", "forced"]
            if let main = sameLang.first(where: { t in
                !extras.contains(where: { t.title.lowercased().contains($0) })
            }) { return main }
            // 4. Còn lại: track đầu tiên cùng ngôn ngữ
            return sameLang.first
        }

        if let lang = d.string(forKey: PrefKey.audioLang),
           let t = pick(tracks(type: "audio"), lang: lang, title: d.string(forKey: PrefKey.audioTitle)) {
            mpv_set_property_string(mpv, "aid", String(t.id))
        }

        if let lang = d.string(forKey: PrefKey.subLang) {
            if lang == PrefKey.subOff {
                mpv_set_property_string(mpv, "sid", "no")
            } else if let t = pick(tracks(type: "sub"), lang: lang, title: d.string(forKey: PrefKey.subTitle)) {
                mpv_set_property_string(mpv, "sid", String(t.id))
            }
        }
    }

    func seek(by seconds: Int) {
        guard let mpv = mpv else { return }
        mpv_command_string(mpv, "seek \(seconds) relative")
    }
}

extension MPVMetalPlayerView.Coordinator {
    func subtitleTracks() -> [MPVTrack] { player?.tracks(type: "sub") ?? [] }
    func audioTracks() -> [MPVTrack] { player?.tracks(type: "audio") ?? [] }
    func selectSubtitle(_ track: MPVTrack?) { player?.selectSubtitle(track) }
    func selectAudio(_ track: MPVTrack) { player?.selectAudio(track) }
    func seek(by seconds: Int) { player?.seek(by: seconds) }
    func togglePause() { player?.togglePause() }
    var isPaused: Bool { player?.isPaused ?? false }
}

// MARK: - View

struct ContentView: View {
    @ObservedObject var coordinator = MPVMetalPlayerView.Coordinator()
    @State var loading = false
    @State private var showImporter = false
    @State private var openedURL: URL?

    @State private var subTracks: [MPVTrack] = []
    @State private var audioTracks: [MPVTrack] = []
    @State private var isPaused = false
    @State private var controlsVisible = true
    @State private var lastInteraction = Date()
    private let hideTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var showSubDialog = false
    @State private var showAudioDialog = false

    private let seekStep = 10
    private let longSeekStep = 60

    var body: some View {
        VStack {
            MPVMetalPlayerView(coordinator: coordinator)
                .onPropertyChange { player, propertyName, propertyData in
                    switch propertyName {
                    case MPVProperty.pausedForCache:
                        loading = propertyData as! Bool
                    default: break
                    }
                }
        }
        .overlay {
            // Lớp bắt tap trên toàn màn hình để hiện lại các nút
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { showControls() }
        }
        .overlay {
            VStack {
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    controlButton("Open", systemImage: "folder") {
                        showImporter = true
                    }
                    controlButton("-\(longSeekStep)s", systemImage: "gobackward.60") {
                        coordinator.seek(by: -longSeekStep)
                    }
                    controlButton("-\(seekStep)s", systemImage: "gobackward.10") {
                        coordinator.seek(by: -seekStep)
                    }
                    controlButton(isPaused ? "Play" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill") {
                        coordinator.togglePause()
                        isPaused = coordinator.isPaused
                    }
                    controlButton("+\(seekStep)s", systemImage: "goforward.10") {
                        coordinator.seek(by: seekStep)
                    }
                    controlButton("+\(longSeekStep)s", systemImage: "goforward.60") {
                        coordinator.seek(by: longSeekStep)
                    }
                    controlButton("Subtitle", systemImage: "captions.bubble") {
                        subTracks = coordinator.subtitleTracks()
                        showSubDialog = true
                    }
                    .confirmationDialog("Subtitle", isPresented: $showSubDialog, titleVisibility: .visible) {
                        Button(subTracks.contains(where: { $0.selected }) ? "Off" : "✓ Off") {
                            coordinator.selectSubtitle(nil)
                        }
                        ForEach(subTracks) { track in
                            Button(track.displayName) {
                                coordinator.selectSubtitle(track)
                            }
                        }
                    }
                    controlButton("Audio", systemImage: "speaker.wave.2") {
                        audioTracks = coordinator.audioTracks()
                        showAudioDialog = true
                    }
                    .confirmationDialog("Audio", isPresented: $showAudioDialog, titleVisibility: .visible) {
                        ForEach(audioTracks) { track in
                            Button(track.displayName) {
                                coordinator.selectAudio(track)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                }
                .padding(.bottom, 8)
                .opacity(controlsVisible ? 0.5 : 0)
                .allowsHitTesting(controlsVisible)
                .animation(.easeInOut(duration: 0.25), value: controlsVisible)
            }
        }
        .overlay(overlayView)
        .onReceive(hideTimer) { _ in
            guard controlsVisible else { return }
            // Đang pause / đang mở menu hoặc chọn file: giữ nút hiện, tính lại 3s từ lúc đó
            if showSubDialog || showAudioDialog || showImporter || coordinator.isPaused {
                lastInteraction = Date()
                return
            }
            if Date().timeIntervalSince(lastInteraction) >= 3 {
                controlsVisible = false
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url):
                openedURL?.stopAccessingSecurityScopedResource()
                if url.startAccessingSecurityScopedResource() {
                    openedURL = url
                } else {
                    openedURL = nil
                }
                coordinator.play(url)
            case .failure:
                break
            }
        }
    }

    private func showControls() {
        controlsVisible = true
        lastInteraction = Date()
    }

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            lastInteraction = Date()
        }) {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption)
            }
            .frame(minWidth: 56, minHeight: 56)
            .padding(.horizontal, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        if loading {
            ProgressView()
        } else {
            EmptyView()
        }
    }
}
