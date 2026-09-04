import Testing
@testable import AetherPlayer

struct PlaybackSourceTransitionTests {
    @Test func standaloneOpenClearsPriorFolderSession() {
        let transition = PlaybackSourceTransition.commit(from: .folderPlaylist, to: .standalone)

        #expect(transition.clearsPlaylist)
        #expect(transition.stopsFileScope)
        #expect(transition.stopsFolderScope)
        #expect(transition.stopsPlaylistScopes)
    }

    @Test func recentOpenClearsPriorFolderSession() {
        let transition = PlaybackSourceTransition.commit(from: .folderPlaylist, to: .recent)

        #expect(transition.clearsPlaylist)
        #expect(transition.stopsFileScope)
        #expect(transition.stopsFolderScope)
        #expect(transition.stopsPlaylistScopes)
    }

    @Test func folderOpenReplacesOldScopesBeforeInstallingPlaylist() {
        let transition = PlaybackSourceTransition.commit(from: .folderPlaylist, to: .folderPlaylist)

        #expect(!transition.clearsPlaylist)
        #expect(transition.stopsFileScope)
        #expect(transition.stopsFolderScope)
        #expect(transition.stopsPlaylistScopes)
    }

    @Test func failedLoadClearsEveryActiveResource() {
        let transition = PlaybackSourceTransition.commit(from: .recent, to: .none)

        #expect(transition.clearsPlaylist)
        #expect(transition.stopsFileScope)
        #expect(transition.stopsFolderScope)
        #expect(transition.stopsPlaylistScopes)
    }

    @Test func manualPlaylistReplacesOldFolderAccess() {
        let transition = PlaybackSourceTransition.commit(from: .folderPlaylist, to: .manualPlaylist)

        #expect(!transition.clearsPlaylist)
        #expect(transition.stopsFolderScope)
        #expect(transition.stopsPlaylistScopes)
    }
}
