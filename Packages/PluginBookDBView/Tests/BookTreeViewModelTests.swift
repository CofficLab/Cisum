import Foundation
import MagicKit
import ProviderBook
import Testing

@testable import PluginBookDBView

// MARK: - BookTreeBuilder Tests

struct BookTreeBuilderTests {
    // MARK: - isSupportedAudioFile

    @Test
    func isSupportedAudioFileRecognizesCommonExtensions() {
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.mp3")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.m4b")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.m4a")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.flac")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.wav")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.aiff")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.aac")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.ogg")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.opus")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.alac")))
    }

    @Test
    func isSupportedAudioFileIsCaseInsensitive() {
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.MP3")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.M4B")))
        #expect(BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/chapter.FLAC")))
    }

    @Test
    func isSupportedAudioFileRejectsNonAudioExtensions() {
        #expect(!BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/cover.jpg")))
        #expect(!BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/notes.txt")))
        #expect(!BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/readme.md")))
        #expect(!BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/data.json")))
        #expect(!BookTreeBuilder.isSupportedAudioFile(URL(fileURLWithPath: "/tmp/no-extension")))
    }

    // MARK: - buildRootChildren

    @Test
    func buildRootChildrenReturnsEmptyForNonExistentDirectory() {
        let nonExistent = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString)", isDirectory: true)
        let children = BookTreeBuilder.buildRootChildren(from: nonExistent)
        #expect(children.isEmpty)
    }

    @Test
    func buildRootChildrenReturnsEmptyForEmptyDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeEmpty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let children = BookTreeBuilder.buildRootChildren(from: root)
        #expect(children.isEmpty)
    }

    @Test
    func buildRootChildrenSkipsHiddenFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeHidden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("audio".utf8).write(to: root.appendingPathComponent("chapter.m4b"))
        try Data("hidden".utf8).write(to: root.appendingPathComponent(".hidden.m4b"))
        try Data("ds-store".utf8).write(to: root.appendingPathComponent(".DS_Store"))

        let children = BookTreeBuilder.buildRootChildren(from: root)

        #expect(children.count == 1)
        #expect(children[0].name == "chapter.m4b")
        #expect(!children[0].isDirectory)
    }

    @Test
    func buildRootChildrenSkipsUnsupportedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeUnsupported-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("audio".utf8).write(to: root.appendingPathComponent("chapter.m4b"))
        try Data("cover".utf8).write(to: root.appendingPathComponent("cover.jpg"))
        try Data("notes".utf8).write(to: root.appendingPathComponent("notes.txt"))

        let children = BookTreeBuilder.buildRootChildren(from: root)

        #expect(children.count == 1)
        #expect(children[0].name == "chapter.m4b")
    }

    @Test
    func buildRootChildrenSortsDirectoriesBeforeFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeOrder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // Create files first to test ordering
        try Data("audio".utf8).write(to: root.appendingPathComponent("01-zzz.m4b"))
        try Data("audio".utf8).write(to: root.appendingPathComponent("02-aaa.m4b"))

        let subDir = root.appendingPathComponent("AAA_Disc1", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: subDir.appendingPathComponent("chapter.m4b"))

        let children = BookTreeBuilder.buildRootChildren(from: root)

        #expect(children.count == 3)
        // Directories come first
        #expect(children[0].isDirectory)
        #expect(children[0].name == "AAA_Disc1")
        // Files come after, sorted by name
        #expect(!children[1].isDirectory)
        #expect(!children[2].isDirectory)
    }

    @Test
    func buildRootChildrenRecursivelyScansNestedDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeNested-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let disc1 = root.appendingPathComponent("Disc 1", isDirectory: true)
        let disc2 = root.appendingPathComponent("Disc 2", isDirectory: true)
        try FileManager.default.createDirectory(at: disc1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: disc2, withIntermediateDirectories: true)

        try Data("audio".utf8).write(to: disc1.appendingPathComponent("01.m4b"))
        try Data("audio".utf8).write(to: disc1.appendingPathComponent("02.m4b"))
        try Data("audio".utf8).write(to: disc2.appendingPathComponent("01.mp3"))

        let children = BookTreeBuilder.buildRootChildren(from: root)

        #expect(children.count == 2)
        #expect(children[0].name == "Disc 1")
        #expect(children[0].isDirectory)
        #expect(children[0].children?.count == 2)

        #expect(children[1].name == "Disc 2")
        #expect(children[1].isDirectory)
        #expect(children[1].children?.count == 1)
    }

    @Test
    func buildRootChildrenSortsByNameLocalized() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeSort-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("audio".utf8).write(to: root.appendingPathComponent("chapter-03.m4b"))
        try Data("audio".utf8).write(to: root.appendingPathComponent("chapter-01.m4b"))
        try Data("audio".utf8).write(to: root.appendingPathComponent("chapter-02.m4b"))

        let children = BookTreeBuilder.buildRootChildren(from: root)

        #expect(children.map(\.name) == ["chapter-01.m4b", "chapter-02.m4b", "chapter-03.m4b"])
    }
}

// MARK: - BookTreeNode Tests

struct BookTreeNodeTests {
    @Test
    func fileNodeIsNotExpandable() {
        let node = BookTreeNode(
            url: URL(fileURLWithPath: "/tmp/chapter.m4b"),
            name: "chapter.m4b",
            isDirectory: false,
            children: nil
        )

        #expect(!node.isExpandable)
        #expect(node.childCount == 0)
    }

    @Test
    func directoryWithChildrenIsExpandable() {
        let children = [
            BookTreeNode(
                url: URL(fileURLWithPath: "/tmp/book/01.m4b"),
                name: "01.m4b",
                isDirectory: false,
                children: nil
            )
        ]
        let node = BookTreeNode(
            url: URL(fileURLWithPath: "/tmp/book"),
            name: "book",
            isDirectory: true,
            children: children
        )

        #expect(node.isExpandable)
        #expect(node.childCount == 1)
    }

    @Test
    func emptyDirectoryIsNotExpandable() {
        let node = BookTreeNode(
            url: URL(fileURLWithPath: "/tmp/empty"),
            name: "empty",
            isDirectory: true,
            children: []
        )

        #expect(!node.isExpandable)
        #expect(node.childCount == 0)
    }

    @Test
    func nodeIdIsURL() {
        let url = URL(fileURLWithPath: "/tmp/chapter.m4b")
        let node = BookTreeNode(url: url, name: "chapter.m4b", isDirectory: false, children: nil)
        #expect(node.id == url)
    }

    @Test
    func nodesWithSameURLAreEqual() {
        let url = URL(fileURLWithPath: "/tmp/chapter.m4b")
        let node1 = BookTreeNode(url: url, name: "chapter.m4b", isDirectory: false, children: nil)
        let node2 = BookTreeNode(url: url, name: "chapter.m4b", isDirectory: false, children: nil)
        #expect(node1 == node2)
    }
}

// MARK: - BookTreeViewModel Tests

@MainActor
struct BookTreeViewModelTests {
    // MARK: - Initialization

    @Test
    func initHasEmptyState() {
        let viewModel = BookTreeViewModel(disk: { nil })

        #expect(viewModel.children.isEmpty)
        #expect(!viewModel.isLoading)
    }

    // MARK: - Loading

    @Test
    func handleOnAppearWithNilDiskSetsIsLoadingFalse() async throws {
        let viewModel = BookTreeViewModel(disk: { nil })

        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 2.0
        ) { !viewModel.isLoading }

        #expect(!viewModel.isLoading)
        #expect(viewModel.children.isEmpty)
    }

    @Test
    func handleOnAppearLoadsTreeFromDisk() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeVM-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("audio".utf8).write(to: root.appendingPathComponent("chapter-01.m4b"))
        try Data("audio".utf8).write(to: root.appendingPathComponent("chapter-02.mp3"))

        let viewModel = BookTreeViewModel(disk: { root })

        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false after loading",
            timeout: 3.0
        ) { !viewModel.isLoading }

        #expect(!viewModel.isLoading)
        #expect(viewModel.children.count == 2)
        #expect(viewModel.children[0].name == "chapter-01.m4b")
        #expect(viewModel.children[1].name == "chapter-02.mp3")
    }

    @Test
    func handleOnAppearWithNestedStructureBuildsTree() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeVMNested-\(UUID().uuidString)", isDirectory: true)
        let disc1 = root.appendingPathComponent("Disc 1", isDirectory: true)
        try FileManager.default.createDirectory(at: disc1, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("audio".utf8).write(to: disc1.appendingPathComponent("01.m4b"))
        try Data("audio".utf8).write(to: disc1.appendingPathComponent("02.m4b"))

        let viewModel = BookTreeViewModel(disk: { root })

        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 3.0
        ) { !viewModel.isLoading }

        #expect(viewModel.children.count == 1)
        #expect(viewModel.children[0].name == "Disc 1")
        #expect(viewModel.children[0].isDirectory)
        #expect(viewModel.children[0].children?.count == 2)
    }

    @Test
    func handleOnAppearWithEmptyDirectoryReturnsEmptyChildren() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeVMEmpty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let viewModel = BookTreeViewModel(disk: { root })

        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 3.0
        ) { !viewModel.isLoading }

        #expect(!viewModel.isLoading)
        #expect(viewModel.children.isEmpty)
    }

    // MARK: - Guard against double loading

    @Test
    func handleOnAppearWhileLoadingDoesNotStartNewLoad() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookTreeVMGuard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("audio".utf8).write(to: root.appendingPathComponent("chapter.m4b"))

        let viewModel = BookTreeViewModel(disk: { root })

        // Multiple rapid calls
        viewModel.handleOnAppear()
        viewModel.handleOnAppear()

        await DeterministicWait.expect(
            "viewModel.isLoading should become false",
            timeout: 3.0
        ) { !viewModel.isLoading }

        #expect(!viewModel.isLoading)
        #expect(viewModel.children.count == 1)
    }
}
