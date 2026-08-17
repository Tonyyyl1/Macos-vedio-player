import Foundation
import Testing
import AetherEngine

@Suite("Tier 1 media fixtures", .serialized)
struct FixtureProbeTests {
    private static var fixtureRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // AetherPlayerTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("Fixtures", isDirectory: true)
    }

    private func fixtureURL(_ relativePath: String) throws -> URL {
        let url = Self.fixtureRoot.appendingPathComponent(relativePath)
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw NSError(
                domain: "FixtureProbeTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing fixture at \(url.path)"]
            )
        }
        return url
    }

    private func probe(_ relativePath: String) throws -> SourceProbe {
        try AetherEngine.probe(url: fixtureURL(relativePath))
    }

    @Test func probesMP4H264AndAAC() throws {
        let result = try probe("mp4/h264-aac.mp4")

        #expect(result.durationSeconds > 0)
        #expect(result.videoCodecName?.lowercased() == "h264")
        #expect(result.audioTracks.contains { $0.codec.lowercased() == "aac" })
    }

    @Test func probesMOVH264AndAAC() throws {
        let result = try probe("mov/h264-aac.mov")

        #expect(result.durationSeconds > 0)
        #expect(result.videoCodecName?.lowercased() == "h264")
        #expect(result.audioTracks.contains { $0.codec.lowercased() == "aac" })
    }

    @Test func probesMatroskaWithSRT() throws {
        let result = try probe("mkv/h264-aac-srt.mkv")

        #expect(result.durationSeconds > 0)
        #expect(result.videoCodecName?.lowercased() == "h264")
        #expect(result.audioTracks.contains { $0.codec.lowercased() == "aac" })
        // FFmpeg calls this stream `subrip`; AetherEngine normalizes the
        // track metadata it exposes to the host as `srt`.
        guard result.subtitleTracks.contains(where: { $0.codec.lowercased() == "srt" }) else {
            throw NSError(
                domain: "FixtureProbeTests",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Expected srt subtitle track; engine reported \(result.subtitleTracks.map(\.codec))"
                ]
            )
        }
    }

    @Test func probesMatroskaHEVCMain10() throws {
        let result = try probe("mkv/hevc-main10-aac.mkv")

        #expect(result.durationSeconds > 0)
        #expect(result.videoCodecName?.lowercased() == "hevc")
        #expect(result.audioTracks.contains { $0.codec.lowercased() == "aac" })
    }

    @Test func probesMatroskaHEVCMain10EAC3AndSRT() throws {
        let result = try probe("mkv/hevc-main10-eac3-srt.mkv")

        #expect(result.durationSeconds > 0)
        #expect(result.videoCodecName?.lowercased() == "hevc")
        #expect(result.audioTracks.contains { $0.codec.lowercased() == "eac3" })
        #expect(result.subtitleTracks.contains { $0.codec.lowercased() == "srt" })
    }

    func probesMatroskaVP9AndPGS() throws {
        let result = try probe("pgs/mkv-vp9-pgs.mkv")

        #expect(result.durationSeconds > 0)
        #expect(result.videoCodecName?.lowercased() == "vp9")
        #expect(result.subtitleTracks.contains { $0.codec.lowercased() == "pgssub" })
    }

    @Test func probesHDR10HEVCWithPQBT2020Signalling() throws {
        let result = try probe("hdr/mkv-hevc-main10-hdr10.mkv")

        #expect(result.durationSeconds > 0)
        #expect(result.videoCodecName?.lowercased() == "hevc")
        #expect(result.videoFormat == .hdr10)
    }

    @Test func probesWebMVP9AndOpus() throws {
        let result = try probe("webm/vp9-opus.webm")

        #expect(result.durationSeconds > 0)
        #expect(result.videoCodecName?.lowercased() == "vp9")
        #expect(result.audioTracks.contains { $0.codec.lowercased() == "opus" })
    }

    @Test func probesWebMAV1MainAndOpus() throws {
        let result = try probe("webm/av1-opus.webm")

        #expect(result.durationSeconds > 0)
        #expect(result.videoCodecName?.lowercased() == "av1")
        #expect(result.audioTracks.contains { $0.codec.lowercased() == "opus" })
    }

    @Test func decodesAFirstFrameForEveryReadyVideoFixture() throws {
        let fixtures = [
            "mp4/h264-aac.mp4",
            "mov/h264-aac.mov",
            "mkv/h264-aac-srt.mkv",
            "mkv/hevc-main10-aac.mkv",
            "mkv/hevc-main10-eac3-srt.mkv",
            "hdr/mkv-hevc-main10-hdr10.mkv",
            "webm/vp9-opus.webm",
            "webm/av1-opus.webm",
            "pgs/mkv-vp9-pgs.mkv"
        ]

        for fixture in fixtures {
            let startedAt = ContinuousClock.now
            let result = try AetherEngine.swDecodeProbe(url: fixtureURL(fixture))
            let elapsed = startedAt.duration(to: .now)
            guard result.openSucceeded, result.framesDecoded > 0,
                  result.firstFrameWidth > 0, result.firstFrameHeight > 0 else {
                throw NSError(
                    domain: "FixtureProbeTests",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey: "First-frame decode failed for \(fixture): open=\(result.openSucceeded), frames=\(result.framesDecoded), error=\(result.firstError ?? "none")"
                    ]
                )
            }
            if fixture == "webm/vp9-opus.webm" || fixture == "webm/av1-opus.webm" {
                #expect(elapsed < .seconds(3), "\(fixture) first-frame decode exceeded the 3 second baseline: \(elapsed)")
            }
        }
    }

    @MainActor
    @Test func loadsAdvancesSeeksAndStopsEveryReadyVideoFixture() async throws {
        for fixture in [
            "mp4/h264-aac.mp4",
            "mov/h264-aac.mov",
            "mkv/h264-aac-srt.mkv",
            "mkv/hevc-main10-aac.mkv",
            "mkv/hevc-main10-eac3-srt.mkv",
            "hdr/mkv-hevc-main10-hdr10.mkv",
            "webm/vp9-opus.webm",
            "webm/av1-opus.webm"
        ] {
            try await exerciseRuntimeSmoke(fixture)
        }
    }

    @MainActor
    @Test func activatesTheEmbeddedSRTTrackAndPublishesItsCue() async throws {
        let engine = try AetherEngine()
        defer { engine.stop() }

        var options = LoadOptions()
        options.suppressDisplayCriteria = true
        options.matchContentEnabled = false
        try await engine.load(url: fixtureURL("mkv/h264-aac-srt.mkv"), options: options)
        guard let subtitle = engine.subtitleTracks.first(where: { $0.codec.lowercased() == "srt" }) else {
            throw NSError(
                domain: "FixtureProbeTests",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Loaded Matroska fixture has no Engine SRT track"]
            )
        }

        engine.selectSubtitleTrack(index: subtitle.id)
        engine.play()
        let cuePublished = await wait(upTo: 4) {
            engine.isSubtitleActive
                && engine.activeSubtitleTrackIndex == subtitle.id
                && engine.subtitleCues.contains { cue in
                    if case let .text(text) = cue.body {
                        return text.contains("AetherPlayer fixture subtitle")
                    }
                    return false
                }
        }
        guard cuePublished else {
            throw NSError(
                domain: "FixtureProbeTests",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "SRT selection did not publish the expected cue; active=\(engine.isSubtitleActive), selected=\(String(describing: engine.activeSubtitleTrackIndex)), cues=\(engine.subtitleCues.count)"]
            )
        }
    }

    @MainActor
    @Test func activatesEAC3AndTheEmbeddedSRTTrack() async throws {
        let engine = try AetherEngine()
        defer { engine.stop() }

        var options = LoadOptions()
        options.suppressDisplayCriteria = true
        options.matchContentEnabled = false
        try await engine.load(url: fixtureURL("mkv/hevc-main10-eac3-srt.mkv"), options: options)
        guard let audio = engine.audioTracks.first(where: { $0.codec.lowercased() == "eac3" }) else {
            throw NSError(domain: "FixtureProbeTests", code: 11, userInfo: [
                NSLocalizedDescriptionKey: "Loaded E-AC-3 fixture has no E-AC-3 track; engine reported \(engine.audioTracks.map(\.codec))"
            ])
        }
        guard let subtitle = engine.subtitleTracks.first(where: { $0.codec.lowercased() == "srt" }) else {
            throw NSError(domain: "FixtureProbeTests", code: 12, userInfo: [
                NSLocalizedDescriptionKey: "Loaded E-AC-3 fixture has no Engine SRT track; engine reported \(engine.subtitleTracks.map(\.codec))"
            ])
        }

        engine.selectAudioTrack(index: audio.id)
        engine.selectSubtitleTrack(index: subtitle.id)
        engine.play()
        let cuePublished = await wait(upTo: 4) {
            engine.activeAudioTrackIndex == audio.id
                && engine.isSubtitleActive
                && engine.activeSubtitleTrackIndex == subtitle.id
                && engine.subtitleCues.contains { cue in
                    if case let .text(text) = cue.body {
                        return text.contains("AetherPlayer fixture subtitle")
                    }
                    return false
                }
        }
        guard cuePublished else {
            throw NSError(domain: "FixtureProbeTests", code: 13, userInfo: [
                NSLocalizedDescriptionKey: "E-AC-3/SRT selection did not become active; audio=\(String(describing: engine.activeAudioTrackIndex)), subtitle=\(String(describing: engine.activeSubtitleTrackIndex)), cues=\(engine.subtitleCues.count), backend=\(engine.playbackBackend)"
            ])
        }
    }

    @MainActor
    func activatesTheEmbeddedPGSTrackAndPublishesItsBitmapCue() async throws {
        let engine = try AetherEngine()
        defer { engine.stop() }

        var options = LoadOptions()
        options.suppressDisplayCriteria = true
        options.matchContentEnabled = false
        options.preferredSubtitleLanguages = ["eng"]
        try await engine.load(url: fixtureURL("pgs/mkv-vp9-pgs.mkv"), options: options)
        guard let subtitle = engine.subtitleTracks.first(where: { $0.codec.lowercased() == "pgssub" }) else {
            throw NSError(domain: "FixtureProbeTests", code: 14, userInfo: [
                NSLocalizedDescriptionKey: "Loaded PGS fixture has no Engine PGS track; engine reported \(engine.subtitleTracks.map(\.codec))"
            ])
        }
        guard engine.playbackBackend == .software else {
            let decoder = engine.activeVideoDecoder ?? "unavailable"
            throw NSError(domain: "FixtureProbeTests", code: 22, userInfo: [
                NSLocalizedDescriptionKey: "VP9/PGS fixture did not select the software route; backend=\(engine.playbackBackend), decoder=\(decoder)"
            ])
        }

        guard engine.activeSubtitleTrackIndex == subtitle.id, engine.isSubtitleActive else {
            throw NSError(domain: "FixtureProbeTests", code: 23, userInfo: [
                NSLocalizedDescriptionKey: "PGS fixture did not activate its preferred English track during load; active=\(engine.isSubtitleActive), selected=\(String(describing: engine.activeSubtitleTrackIndex))"
            ])
        }
        engine.play()
        let cuePublished = await wait(upTo: 14) {
            engine.isSubtitleActive
                && engine.activeSubtitleTrackIndex == subtitle.id
                && engine.subtitleCues.contains { cue in
                    if case .image = cue.body { return true }
                    return false
                }
        }
        guard cuePublished else {
            throw NSError(domain: "FixtureProbeTests", code: 15, userInfo: [
                NSLocalizedDescriptionKey: "PGS selection did not publish a bitmap cue; active=\(engine.isSubtitleActive), selected=\(String(describing: engine.activeSubtitleTrackIndex)), cues=\(engine.subtitleCues.count), state=\(engine.state), time=\(engine.currentTime), backend=\(engine.playbackBackend)"
            ])
        }
        await engine.seek(to: 0.5)
        guard await wait(upTo: 4, until: { abs(engine.currentTime - 0.5) < 0.35 }) else {
            throw NSError(domain: "FixtureProbeTests", code: 24, userInfo: [
                NSLocalizedDescriptionKey: "PGS seek did not land near 0.5s; state=\(engine.state), time=\(engine.currentTime), backend=\(engine.playbackBackend)"
            ])
        }
        engine.stop()
        #expect(engine.state == .idle)
    }

    @MainActor
    @Test func loadsHDR10WithSourceAndOutputFormatSignalling() async throws {
        let engine = try AetherEngine()
        defer { engine.stop() }

        var options = LoadOptions()
        options.suppressDisplayCriteria = true
        options.matchContentEnabled = false
        options.panelIsInHDRMode = true
        try await engine.load(url: fixtureURL("hdr/mkv-hevc-main10-hdr10.mkv"), options: options)
        guard engine.sourceVideoFormat == .hdr10, engine.videoFormat == .hdr10 else {
            let decoder = engine.activeVideoDecoder ?? "unavailable"
            throw NSError(domain: "FixtureProbeTests", code: 16, userInfo: [
                NSLocalizedDescriptionKey: "HDR10 fixture lost its PQ/BT.2020 signal; source=\(engine.sourceVideoFormat), output=\(engine.videoFormat), backend=\(engine.playbackBackend), decoder=\(decoder)"
            ])
        }

        engine.play()
        let startedAt = engine.currentTime
        guard await wait(upTo: 4, until: { engine.currentTime > startedAt + 0.15 }) else {
            throw NSError(domain: "FixtureProbeTests", code: 17, userInfo: [
                NSLocalizedDescriptionKey: "HDR10 playback clock did not advance; state=\(engine.state), time=\(engine.currentTime), backend=\(engine.playbackBackend)"
            ])
        }
        await engine.seek(to: 0.5)
        guard await wait(upTo: 4, until: { abs(engine.currentTime - 0.5) < 0.35 }) else {
            throw NSError(domain: "FixtureProbeTests", code: 18, userInfo: [
                NSLocalizedDescriptionKey: "HDR10 seek did not land near 0.5s; state=\(engine.state), time=\(engine.currentTime), backend=\(engine.playbackBackend)"
            ])
        }
        engine.stop()
        #expect(engine.state == .idle)
    }

    @MainActor
    @Test func rejectsTheTruncatedMP4WithoutPermanentLoading() async throws {
        let url = try fixtureURL("malformed/truncated.mp4")
        do {
            _ = try AetherEngine.probe(url: url)
            throw NSError(domain: "FixtureProbeTests", code: 19, userInfo: [
                NSLocalizedDescriptionKey: "Malformed fixture unexpectedly passed SourceProbe"
            ])
        } catch let error as NSError where error.domain == "FixtureProbeTests" {
            throw error
        } catch {
            // Expected probe failure; playback is checked independently below.
        }

        let engine = try AetherEngine()
        defer { engine.stop() }
        var options = LoadOptions()
        options.suppressDisplayCriteria = true
        options.matchContentEnabled = false
        var loadFailed = false
        do {
            try await engine.load(url: url, options: options)
        } catch {
            loadFailed = true
        }
        if case .error = engine.state { loadFailed = true }
        guard loadFailed else {
            throw NSError(domain: "FixtureProbeTests", code: 20, userInfo: [
                NSLocalizedDescriptionKey: "Malformed fixture unexpectedly loaded; state=\(engine.state), backend=\(engine.playbackBackend)"
            ])
        }
        guard engine.state != .loading else {
            throw NSError(domain: "FixtureProbeTests", code: 21, userInfo: [
                NSLocalizedDescriptionKey: "Malformed fixture left the player permanently loading"
            ])
        }
        engine.stop()
        #expect(engine.state == .idle)
    }

    @MainActor
    @Test func reachesNaturalEndForTheMP4SmokeFixture() async throws {
        let engine = try AetherEngine()
        defer { engine.stop() }

        var options = LoadOptions()
        options.suppressDisplayCriteria = true
        options.matchContentEnabled = false
        try await engine.load(url: fixtureURL("mp4/h264-aac.mp4"), options: options)
        engine.play()

        let reachedEnd = await wait(upTo: 6) { engine.state == .ended }
        guard reachedEnd else {
            throw NSError(
                domain: "FixtureProbeTests",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "MP4 fixture did not reach .ended; state=\(engine.state), time=\(engine.currentTime), duration=\(engine.duration)"]
            )
        }
    }

    @MainActor
    private func exerciseRuntimeSmoke(_ fixture: String) async throws {
        let engine = try AetherEngine()
        defer { engine.stop() }

        var options = LoadOptions()
        options.suppressDisplayCriteria = true
        options.matchContentEnabled = false
        try await engine.load(url: fixtureURL(fixture), options: options)
        guard engine.playbackBackend != .none else {
            throw NSError(
                domain: "FixtureProbeTests",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: "No playback route selected for \(fixture)"]
            )
        }
        if fixture == "webm/av1-opus.webm" {
            guard engine.playbackBackend == .native || engine.playbackBackend == .software else {
                let decoder = engine.activeVideoDecoder ?? "unavailable"
                throw NSError(
                    domain: "FixtureProbeTests",
                    code: 10,
                    userInfo: [
                        NSLocalizedDescriptionKey: "AV1 selected an unsupported playback route for \(fixture); backend=\(engine.playbackBackend), state=\(engine.state), decoder=\(decoder)"
                    ]
                )
            }
        }
        engine.play()

        let startedAt = engine.currentTime
        let clockAdvanced = await wait(upTo: 4) {
            engine.currentTime > startedAt + 0.15
        }
        guard clockAdvanced else {
            throw NSError(
                domain: "FixtureProbeTests",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Playback clock did not advance for \(fixture); state=\(engine.state), time=\(engine.currentTime)"]
            )
        }

        await engine.seek(to: 0.5)
        let seekLanded = await wait(upTo: 4) {
            abs(engine.currentTime - 0.5) < 0.35
        }
        guard seekLanded else {
            throw NSError(
                domain: "FixtureProbeTests",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Seek did not land near 0.5s for \(fixture); state=\(engine.state), time=\(engine.currentTime)"]
            )
        }

        engine.stop()
        #expect(engine.state == .idle)
    }

    @MainActor
    private func wait(upTo seconds: Double, until condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }
}
