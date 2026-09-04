import AVFoundation
import CoreMedia

/// Builds `AVMetadataItem`s for `AetherEngine.setExternalMetadata`. AVKit republishes these
/// as the lock-screen / Control Center Now Playing info; we never touch MPNowPlayingInfoCenter
/// directly (see PlayerHostController.stageNowPlaying).
enum NowPlayingMetadata {
    static func items(title: String, artwork: PlatformImage?) -> [AVMetadataItem] {
        var out: [AVMetadataItem] = []
        let t = AVMutableMetadataItem()
        t.identifier = .commonIdentifierTitle
        t.value = title as NSString
        out.append(t)
        if let artwork, let data = artwork.pngDataCompat {
            let a = AVMutableMetadataItem()
            a.identifier = .commonIdentifierArtwork
            a.value = data as NSData
            a.dataType = kCMMetadataBaseDataType_PNG as String
            out.append(a)
        }
        return out
    }
}

private extension PlatformImage {
    var pngDataCompat: Data? {
        #if os(iOS)
        return pngData()
        #else
        return nil
        #endif
    }
}
