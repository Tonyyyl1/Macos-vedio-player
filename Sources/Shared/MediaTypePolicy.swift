import Foundation
import UniformTypeIdentifiers

/// The one place that defines files AetherPlayer presents as playable.
///
/// `project.yml` mirrors the public type identifiers below for Finder/Open With.
/// Keep the extension lists here for code paths that enumerate a folder, where
/// Launch Services does not provide a type for every child URL.
enum MediaTypePolicy {
    static let videoExtensions: Set<String> = [
        "mkv", "matroska", "mp4", "m4v", "mov", "webm", "ts", "m2ts", "avi", "ogv", "ogg", "flv"
    ]

    static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "wav", "aiff", "aif",
        "opus", "oga", "wma", "mka", "ape", "dsf", "wv"
    ]

    static let discImageExtensions: Set<String> = ["iso"]

    static let playableExtensions = videoExtensions
        .union(audioExtensions)
        .union(discImageExtensions)

    /// Shared by macOS open panels and the iOS Files picker. `matroska` stays
    /// explicit because neither of its extensions is consistently classified
    /// as `public.movie` by the system.
    static let playableContentTypes: [UTType] = [
        .movie, .video, .matroska, .mpeg4Movie, .audio, .discImage
    ]

    static func isPlayable(_ url: URL) -> Bool {
        playableExtensions.contains(url.pathExtension.lowercased())
    }
}

extension UTType {
    /// ISO 9660 / UDF disc image (DVD / Blu-ray). Falls back to `.iso` when
    /// the system does not expose the UTI.
    static let discImage = UTType("public.iso-image") ?? UTType(filenameExtension: "iso") ?? .data

    /// The imported type declared in every target's Info.plist source.
    static let matroska = UTType("org.matroska.mkv") ?? UTType(filenameExtension: "mkv") ?? .movie
}
