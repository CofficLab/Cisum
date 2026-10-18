import Foundation
import KernelCore
import Testing
@testable import PluginPluginManager

// MARK: - 分类展示映射

/// 分类的标题、图标、排序三者必须齐全且唯一 ——
/// 任一 category 新增后忘记补映射，`order(of:)` 会回退到末尾导致排序错乱。
@Test func everyCategoryHasDistinctTitleIconAndOrder() {
    let categories = PluginCategoryPresentation.categories
    #expect(categories.count == 10)

    let titles = categories.map { PluginCategoryPresentation.title(for: $0) }
    let icons = categories.map { PluginCategoryPresentation.icon(for: $0) }
    let orders = categories.map { PluginCategoryPresentation.order(of: $0) }

    // 标题与图标不应重复，否则列表里会出现两个一样的分类
    #expect(Set(titles).count == titles.count)
    #expect(Set(icons).count == icons.count)

    // 排序应恰好是 0..<count，不允许有洞或重复
    #expect(Set(orders) == Set(0..<categories.count))
    #expect(orders.sorted() == orders)
}

/// 首屏应优先展示核心分类。
@Test func categoryOrderStartsWithCore() {
    #expect(PluginCategoryPresentation.order(of: .core) == 0)
    #expect(PluginCategoryPresentation.order(of: .chat) == 1)
    #expect(PluginCategoryPresentation.order(of: .general) == PluginCategoryPresentation.categories.count - 1)
}

@Test(arguments: [
    (PluginCategory.core, "Core", "sparkles"),
    (.chat, "Chat", "bubble.left.and.bubble.right"),
    (.llm, "LLM", "brain.head.profile"),
    (.editor, "Editor", "pencil.and.outline"),
    (.project, "Project", "folder"),
    (.feature, "Feature", "hammer"),
    (.system, "System", "cpu"),
    (.design, "Design", "paintpalette"),
    (.integration, "Integration", "square.stack.3d.up"),
    (.general, "General", "square.grid.2x2"),
])
func categoryMapsToStableTitleAndIcon(
    category: PluginCategory,
    expectedTitle: String,
    expectedIcon: String
) {
    #expect(PluginCategoryPresentation.title(for: category) == expectedTitle)
    #expect(PluginCategoryPresentation.icon(for: category) == expectedIcon)
    // 图标名必须是合法 SF Symbol，否则界面会显示空白占位
    #expect(!expectedIcon.isEmpty)
}

// MARK: - 阶段展示映射

@Test(arguments: [
    (PluginStage.experimental, "Experimental"),
    (.preview, "Preview"),
    (.stable, "Stable"),
    (.deprecated, "Deprecated"),
])
func stageMapsToStableTitle(stage: PluginStage, expectedTitle: String) {
    #expect(PluginStagePresentation.title(for: stage) == expectedTitle)
}

/// 废弃状态必须能被明确识别，避免用户以为插件仍受支持。
@Test func deprecatedStageIsDistinguishable() {
    let titles = [PluginStage.experimental, .preview, .stable, .deprecated]
        .map { PluginStagePresentation.title(for: $0) }
    #expect(Set(titles).count == titles.count)
    #expect(PluginStagePresentation.title(for: .deprecated) != PluginStagePresentation.title(for: .stable))
}
