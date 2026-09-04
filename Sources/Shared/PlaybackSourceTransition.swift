import Foundation

/// Describes where the active playback URL came from. The kind controls the
/// lifetime of a security-scoped file or folder resource and whether playlist
/// navigation remains valid after a successful load.
enum PlaybackSourceKind: Equatable, Sendable {
    case none
    case standalone
    case recent
    case folderPlaylist
    case manualPlaylist
}

/// Resource cleanup required when an incoming source becomes the active one.
/// This is deliberately pure so the PlayerViewModel's source transitions can
/// be tested without constructing AetherEngine or a real security bookmark.
struct PlaybackSourceTransition: Equatable, Sendable {
    let clearsPlaylist: Bool
    let stopsFileScope: Bool
    let stopsFolderScope: Bool
    let stopsPlaylistScopes: Bool

    static func commit(from: PlaybackSourceKind, to: PlaybackSourceKind) -> Self {
        switch to {
        case .none, .standalone, .recent:
            // A fresh file, a recent file, and a failed load must not retain
            // navigation or sandbox access from the preceding folder session.
            return Self(clearsPlaylist: true, stopsFileScope: true, stopsFolderScope: true, stopsPlaylistScopes: true)
        case .folderPlaylist, .manualPlaylist:
            // The caller installs the incoming playlist immediately after
            // this cleanup. Releasing every prior scope first makes replacement
            // safe when changing between folders and user-selected playlists.
            return Self(clearsPlaylist: false, stopsFileScope: true, stopsFolderScope: true, stopsPlaylistScopes: true)
        }
    }
}
