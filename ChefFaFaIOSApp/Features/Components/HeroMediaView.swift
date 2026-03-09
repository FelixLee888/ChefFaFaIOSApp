import AVKit
import SwiftUI
import UIKit

struct HeroMediaView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var player = AVPlayer()
    @State private var isVideoVisible = false
    @State private var currentVideoIndex = 0
    @State private var cycleTask: Task<Void, Never>?
    @State private var itemEndObserver: NSObjectProtocol?
    @State private var itemErrorObserver: NSObjectProtocol?

    private let videoFiles = ["fafa_header_video1.mp4", "fafa_header_video2.mp4"]
    private let cycleIntervalSeconds: TimeInterval = 3.0
    private let fadeDurationSeconds: TimeInterval = 0.64

    private var heroHeight: CGFloat {
        horizontalSizeClass == .compact ? 208 : 260
    }

    var body: some View {
        ZStack {
            RecipeImageView(path: "fafa_header.png", cornerRadius: 22, height: heroHeight)

            if hasVideoAssets {
                HeroVideoLayer(player: player)
                    .opacity(isVideoVisible ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.easeInOut(duration: fadeDurationSeconds), value: isVideoVisible)
        .onAppear {
            player.isMuted = true
            handlePlaybackPolicy()
        }
        .onDisappear {
            stopVideoCycle()
        }
        .onChange(of: scenePhase) { _, _ in
            handlePlaybackPolicy()
        }
        .onChange(of: accessibilityReduceMotion) { _, _ in
            handlePlaybackPolicy()
        }
    }

    private func startVideoCycle() {
        stopVideoCycle()
        scheduleNextCycle(after: cycleIntervalSeconds)
    }

    private func stopVideoCycle() {
        cycleTask?.cancel()
        cycleTask = nil
        removeItemObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
        withAnimation(.easeInOut(duration: fadeDurationSeconds)) {
            isVideoVisible = false
        }
    }

    private func handlePlaybackPolicy() {
        let shouldPlay = hasVideoAssets && !accessibilityReduceMotion && scenePhase == .active
        if shouldPlay {
            startVideoCycle()
        } else {
            stopVideoCycle()
        }
    }

    private var hasVideoAssets: Bool {
        !videoURLs.isEmpty
    }

    private var videoURLs: [URL] {
        videoFiles.compactMap { BundledAsset.url(fileName: $0) }
    }

    private func playCurrentVideo() {
        let urls = videoURLs
        guard !urls.isEmpty else { return }
        let clampedIndex = currentVideoIndex % urls.count
        let url = urls[clampedIndex]
        currentVideoIndex = (clampedIndex + 1) % urls.count
        let item = AVPlayerItem(url: url)
        removeItemObservers()
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: fadeDurationSeconds)) {
                isVideoVisible = false
            }
            player.pause()
            scheduleNextCycle(after: cycleIntervalSeconds)
        }
        itemErrorObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            withAnimation(.easeInOut(duration: fadeDurationSeconds)) {
                isVideoVisible = false
            }
            player.pause()
            scheduleNextCycle(after: cycleIntervalSeconds)
        }
        player.replaceCurrentItem(with: item)
        player.seek(to: .zero)
        withAnimation(.easeInOut(duration: fadeDurationSeconds)) {
            isVideoVisible = true
        }
        player.play()
    }

    private func scheduleNextCycle(after seconds: TimeInterval) {
        cycleTask?.cancel()
        cycleTask = Task {
            let nanos = UInt64(max(seconds, 0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            if Task.isCancelled { return }
            await MainActor.run {
                playCurrentVideo()
            }
        }
    }

    private func removeItemObservers() {
        if let itemEndObserver {
            NotificationCenter.default.removeObserver(itemEndObserver)
            self.itemEndObserver = nil
        }
        if let itemErrorObserver {
            NotificationCenter.default.removeObserver(itemErrorObserver)
            self.itemErrorObserver = nil
        }
    }
}

private struct HeroVideoLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        guard let layer = self.layer as? AVPlayerLayer else {
            fatalError("Expected AVPlayerLayer backing layer")
        }
        return layer
    }
}
