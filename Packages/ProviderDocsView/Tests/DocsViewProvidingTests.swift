import KernelCore
import SwiftUI
import Testing
@testable import ProviderDocsView

@MainActor
struct DocsViewProvidingTests {
    @Test
    func defaultProviderAppendsDeduplicatesAndRemovesBothEntryKinds() {
        let provider = DefaultDocsViewProvider()
        let audioAbout = makeEntry(id: "audio", name: "Audio About")
        let audioManual = makeEntry(id: "audio", name: "Audio Manual")
        let storageManual = makeEntry(id: "storage", name: "Storage Manual")

        provider.addAbout(audioAbout)
        provider.addAbout(makeEntry(id: "audio", name: "Duplicate About"))
        provider.addManual(audioManual)
        provider.addManual(storageManual)
        provider.addManual(makeEntry(id: "audio", name: "Duplicate Manual"))

        #expect(provider.aboutEntries.map(\.name) == ["Audio About"])
        #expect(provider.manualEntries.map(\.name) == ["Audio Manual", "Storage Manual"])

        provider.removeEntries(id: "audio")
        #expect(provider.aboutEntries.isEmpty)
        #expect(provider.manualEntries.map(\.id) == ["storage"])
    }

    @Test
    func replacingEntriesReplacesBothCollections() {
        let provider = DefaultDocsViewProvider()
        provider.addAbout(makeEntry(id: "old", name: "Old About"))
        provider.addManual(makeEntry(id: "old", name: "Old Manual"))

        provider.replaceAboutEntries([makeEntry(id: "new", name: "New About")])
        provider.replaceManualEntries([makeEntry(id: "new", name: "New Manual")])

        #expect(provider.aboutEntries.map(\.name) == ["New About"])
        #expect(provider.manualEntries.map(\.name) == ["New Manual"])
    }

    @Test
    func docsEntryBuildsItsViewOnDemand() {
        let counter = ViewBuildCounter()
        let entry = DocsEntry(id: "audio", name: "Audio") {
            CountingManualView(counter: counter)
        }

        #expect(entry.id == "audio")
        #expect(entry.name == "Audio")
        #expect(counter.buildCount == 0)
        _ = entry.makeView()
        #expect(counter.buildCount == 1)
    }

    @Test
    func kernelRegistersAndResolvesDocsProviderAndRejectsDuplicates() throws {
        let kernel = CisumKernelContainer()
        let first = DefaultDocsViewProvider()
        let second = DefaultDocsViewProvider()

        #expect(kernel.docs == nil)
        try kernel.registerDocsService(first)
        #expect(kernel.docs === first)
        #expect(throws: CisumKernelError.self) {
            try kernel.registerDocsService(second)
        }
        #expect(kernel.docs === first)
    }
}

@MainActor
private func makeEntry(id: String, name: String) -> DocsEntry {
    DocsEntry(id: id, name: name) { Text(name) }
}

@MainActor
private final class ViewBuildCounter {
    var buildCount = 0
}

@MainActor
private struct CountingManualView: View {
    init(counter: ViewBuildCounter) {
        counter.buildCount += 1
    }

    var body: some View {
        Text("Manual")
    }
}
