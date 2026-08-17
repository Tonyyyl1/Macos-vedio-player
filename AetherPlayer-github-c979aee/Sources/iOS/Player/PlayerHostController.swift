import AetherEngine
import AVKit
import Combine

@MainActor
final class PlayerHostController: AVPlayerViewController {
    let model: PlayerViewModel
    private var cancellables = Set<AnyCancellable>()
    /// True while a PiP handoff is dismissing the VC, so viewWillDisappear
    /// does not tear playback down. Set synchronously in the PiP delegate.
    nonisolated(unsafe) var pipActive = false
    private let aetherView = AetherPlayerView()
    private var aetherMounted = false

    init(model: PlayerViewModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Keep AVKit's Now Playing / AirPods backend; Plan 1 shows its default chrome.
        showsPlaybackControls = true
        allowsPictureInPicturePlayback = true
        canStartPictureInPictureAutomaticallyFromInline = true
        videoGravity = .resizeAspect
        delegate = self
        model.engine.backgroundPlaybackEnabled = true
        bindEngine()
    }

    private func bindEngine() {
        // Native path (HEVC/H.264/HW-AV1): AVKit renders engine.currentAVPlayer.
        model.engine.$currentAVPlayer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] avPlayer in
                guard let self else { return }
                self.player = avPlayer
                if let avPlayer {
                    avPlayer.allowsExternalPlayback = true
                    avPlayer.usesExternalPlaybackWhileExternalScreenIsActive = true
                    // A new load's player is ready; stage Now Playing even if this
                    // file carries no container metadata (falls back to filename).
                    self.stageNowPlaying()
                }
            }
            .store(in: &cancellables)

        // Stage Now Playing via externalMetadata whenever the engine resolves media
        // metadata; the engine replays it across audio-switch reloads. We never touch
        // MPNowPlayingInfoCenter directly, AVKit owns Now Playing on iOS.
        model.engine.$metadata
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.stageNowPlaying() }
            .store(in: &cancellables)

        // Software-decode path (dav1d AV1, VP9): AetherPlayerView renders into
        // AVKit's content overlay. Also mounted for the legacy `.aether` case.
        model.engine.$playbackBackend
            .receive(on: DispatchQueue.main)
            .sink { [weak self] backend in
                guard let self else { return }
                switch backend {
                case .software, .aether: self.mountAetherIfNeeded()
                case .native, .none, .audio: self.unmountAether()
                }
            }
            .store(in: &cancellables)
    }

    private func mountAetherIfNeeded() {
        guard !aetherMounted, let overlay = contentOverlayView else { return }
        aetherView.translatesAutoresizingMaskIntoConstraints = false
        overlay.insertSubview(aetherView, at: 0)
        NSLayoutConstraint.activate([
            aetherView.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            aetherView.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            aetherView.topAnchor.constraint(equalTo: overlay.topAnchor),
            aetherView.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
        ])
        model.engine.bind(view: aetherView)
        aetherMounted = true
    }

    private func unmountAether() {
        guard aetherMounted else { return }
        model.engine.unbind(view: aetherView)
        aetherView.removeFromSuperview()
        aetherMounted = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        suppressAVKitChrome()
        model.startVolumeObservation()
        PlayerOrientation.engage(locked: model.playerRotationLocked)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        PlayerOrientation.playerMask ?? .allButUpsideDown
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // AVKit fades its chrome back in on layout passes (and rebuilds it lazily after a
        // player swap), so re-suppress every pass rather than once.
        suppressAVKitChrome()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard !pipActive else { return }   // PiP handoff, keep playing
        model.stopVolumeObservation()
        PlayerOrientation.unlock()
        model.stop()
    }

    /// alpha=0 AVKit's own chrome views. `showsPlaybackControls` stays true (it gates the Now
    /// Playing session; setting it false kills Now Playing); only the visible chrome is hidden.
    /// Our own overlay (Plan 1's Close/Tracks buttons, Phase B's custom chrome) is not affected,
    /// it lives outside AVKit's view hierarchy. Class-name matching is runtime introspection, not
    /// private-API dispatch, which App Store review allows.
    private func suppressAVKitChrome() {
        var preserved: Set<ObjectIdentifier> = [ObjectIdentifier(aetherView)]
        if let overlay = contentOverlayView { preserved.insert(ObjectIdentifier(overlay)) }
        hideChrome(on: view, preserve: preserved)
    }

    private func hideChrome(on v: UIView, preserve: Set<ObjectIdentifier>) {
        if preserve.contains(ObjectIdentifier(v)) { return }
        let typeName = String(describing: type(of: v))
        // Keywords matched against AVKit's runtime view hierarchy: Controls (_AVPlayerControlsView),
        // Transport (scrubber), Info (title/_AVPlayerInfoView), Menu (picker rows), Focus (focus container).
        // Verified in production on tvOS (Sodalite) and device-verified on iOS 17 (iPhone 17 Pro):
        // AVKit's chrome is fully hidden on both platforms with this keyword set.
        let isChrome = typeName.contains("Controls")
            || typeName.contains("Transport")
            || typeName.contains("Chrome")
            || typeName.contains("Info")
            || typeName.contains("Focus")
            || typeName.contains("Menu")
        if isChrome {
            v.alpha = 0
            return
        }
        for sub in v.subviews {
            hideChrome(on: sub, preserve: preserve)
        }
    }

    /// Idempotent: safe to call from both the metadata sink and the currentAVPlayer
    /// sink. Title-only for v1; artwork enrichment is a later refinement.
    private func stageNowPlaying() {
        guard let url = model.loadedURL else { return }
        let title = model.metadata?.title ?? url.deletingPathExtension().lastPathComponent
        model.engine.setExternalMetadata(NowPlayingMetadata.items(title: title, artwork: nil))
    }
}
