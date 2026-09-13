import Foundation
import SwiftData
import Testing
@testable import PluginAudioDBData

@Test
func audioModelUsesProvidedMetadataAndFolderFlag() throws {
    let file = URL(fileURLWithPath: "/library/chapter.m4a")
    let model = AudioModel(
        file,
        size: 42,
        title: "  A chapter  \n",
        identifierKey: "chapter-id",
        contentType: "audio/mp4",
        isFolder: true,
        order: 7
    )

    #expect(model.url == file)
    #expect(model.size == 42)
    #expect(model.title == "A chapter")
    #expect(model.identifierKey == "chapter-id")
    #expect(model.contentType == "audio/mp4")
    #expect(model.isFolder)
    #expect(model.order == 7)
    #expect(AudioModel(URL.applicationDirectory, size: 0).children == nil)
    model.randomOrder()
    #expect((101...500_000_000).contains(model.order))
}

@Test
func audioModelDerivesTitleAndSizeFromFileWhenMetadataIsMissing() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("AudioModelBehavior-\(UUID().uuidString)", isDirectory: true)
    let file = root.appendingPathComponent("Sample chapter.mp3")
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data([0x01, 0x02, 0x03]).write(to: file)

    let model = AudioModel(file)

    #expect(model.title == "Sample chapter")
    #expect(model.size == 3)
    #expect((101...500_000_000).contains(model.order))
    #expect(!model.getFileSizeReadable().isEmpty)

    let folder = root.appendingPathComponent("Folder", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data([0x04, 0x05, 0x06, 0x07]).write(to: folder.appendingPathComponent("inside.mp3"))
    let folderModel = AudioModel(folder, isFolder: true)
    #expect(folderModel.isFolder)
    #expect(folderModel.size == 4)
}

@Test
func audioModelFallsBackToFilenameForBlankTitles() {
    let file = URL(fileURLWithPath: "/library/fallback-title.mp3")

    #expect(AudioModel(file, title: " \n\t ").title == "fallback-title")
    #expect(AudioModel(file, title: "").title == "fallback-title")
}

@MainActor
@Test
func audioModelFetchDescriptorsPreserveOrderingAndFolderFilters() throws {
    let schema = Schema([AudioModel.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext
    let first = AudioModel(URL(fileURLWithPath: "/library/first.mp3"), size: 0, order: 10)
    let folder = AudioModel(URL(fileURLWithPath: "/library/folder"), size: 0, isFolder: true, order: 20)
    let last = AudioModel(URL(fileURLWithPath: "/library/last.mp3"), size: 0, order: 30)
    context.insert(first)
    context.insert(folder)
    context.insert(last)

    #expect(try context.fetch(AudioModel.descriptorOrderAsc).map(\.order) == [10, 20, 30])
    #expect(try context.fetch(AudioModel.descriptorOrderDesc).map(\.order) == [30, 20, 10])
    #expect(try context.fetch(AudioModel.descriptorFirst).map(\.order) == [10])
    #expect(try context.fetch(AudioModel.descriptorLast).map(\.order) == [30])
    #expect(try context.fetch(AudioModel.descriptorPrev(order: 30)).map(\.order) == [20])
    #expect(try context.fetch(AudioModel.descriptorNext(order: 10)).map(\.order) == [20])
    #expect(try context.fetch(AudioModel.descriptorAll).map(\.order) == [10, 20, 30])
    #expect(try context.fetch(AudioModel.descriptorNotFolder).map(\.order) == [10, 30])
    #expect(try context.fetch(AudioModel.descriptorFirst).first?.id == first.id)
    #expect(!first.verbose)

    let repository = try AudioRepo(
        container: container,
        disk: URL(fileURLWithPath: "/library", isDirectory: true),
        reason: "AudioModelBehaviorTests"
    )
    first.setDB(repository)
    #expect(first.db === repository)
    first.setDB(nil)
    #expect(first.db == nil)
}
