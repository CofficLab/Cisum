import Foundation
import ProviderVideo
import Testing
@testable import PluginVideoLibrary

struct VideoLibraryContentStateTests {
    private let repository = URL(fileURLWithPath: "/tmp/videos")

    @Test("定位与扫描空仓库时呈现加载态")
    func loadingStates() {
        #expect(resolve(.locating, repositoryURL: nil, itemCount: 0, filteredItemCount: 0) == .loading)
        #expect(resolve(.scanning(repository), repositoryURL: repository, itemCount: 0, filteredItemCount: 0) == .loading)
    }

    @Test("仓库不可用优先于其他内容状态")
    func unavailableRepository() {
        #expect(resolve(.unavailable("Permission denied"), repositoryURL: nil, itemCount: 0, filteredItemCount: 0) == .unavailable("Permission denied"))
        #expect(resolve(.unavailable("Missing"), repositoryURL: repository, itemCount: 2, filteredItemCount: 2) == .unavailable("Missing"))
    }

    @Test("区分无仓库、空仓库、无筛选结果与正常内容")
    func repositoryAndFilterStates() {
        #expect(resolve(.idle, repositoryURL: nil, itemCount: 0, filteredItemCount: 0) == .noRepository)
        #expect(resolve(.ready(repository, 0), repositoryURL: repository, itemCount: 0, filteredItemCount: 0) == .emptyRepository)
        #expect(resolve(.ready(repository, 2), repositoryURL: repository, itemCount: 2, filteredItemCount: 0) == .noMatches)
        #expect(resolve(.ready(repository, 2), repositoryURL: repository, itemCount: 2, filteredItemCount: 1) == .library)
    }

    @Test("后台扫描不会替换已有媒体内容")
    func refreshingKeepsExistingContent() {
        #expect(resolve(.scanning(repository), repositoryURL: repository, itemCount: 2, filteredItemCount: 1) == .library)
        #expect(resolve(.scanning(repository), repositoryURL: repository, itemCount: 2, filteredItemCount: 0) == .noMatches)
    }

    private func resolve(
        _ state: VideoRepositoryState,
        repositoryURL: URL?,
        itemCount: Int,
        filteredItemCount: Int
    ) -> VideoLibraryContentState {
        VideoLibraryContentState.resolve(
            repositoryState: state,
            repositoryURL: repositoryURL,
            itemCount: itemCount,
            filteredItemCount: filteredItemCount
        )
    }
}
