import Foundation
import Testing
@testable import PluginAudioDBView

// MARK: - 列表状态判定

/// 加载中优先于空态：正在拉取时不应闪现「仓库为空」，
/// 否则用户会误判自己的仓库真的没有内容。
@Test func listStatePrefersLoadingOverEmpty() {
    #expect(AudioDBSettingPresentation.listState(
        isLoading: true,
        isLoadingMore: false,
        urlCount: 0,
        hasError: false
    ) == .loading)
}

@Test func listStateIsEmptyOnlyAfterLoadingFinishes() {
    #expect(AudioDBSettingPresentation.listState(
        isLoading: false,
        isLoadingMore: false,
        urlCount: 0,
        hasError: false
    ) == .empty)
}

/// 有数据时即便仍在加载更多，也应保持内容展示，避免列表闪断。
@Test func listStateStaysContentWhileLoadingMore() {
    #expect(AudioDBSettingPresentation.listState(
        isLoading: false,
        isLoadingMore: true,
        urlCount: 42,
        hasError: false
    ) == .content)

    #expect(AudioDBSettingPresentation.listState(
        isLoading: true,
        isLoadingMore: false,
        urlCount: 42,
        hasError: false
    ) == .content)
}

/// 失败态优先级最高，避免用空态掩盖真实错误。
@Test func listStateSurfacesErrorBeforeEmpty() {
    #expect(AudioDBSettingPresentation.listState(
        isLoading: false,
        isLoadingMore: false,
        urlCount: 0,
        hasError: true
    ) == .error(hasError: true))
}

/// 状态判定必须是纯函数：同样输入永远得到同样输出，
/// 否则列表会在多次渲染间跳变。
@Test(arguments: [
    (false, false, 0, false),
    (true, false, 0, false),
    (false, true, 5, false),
    (true, true, 5, false),
    (false, false, 0, true),
])
func listStateIsDeterministic(
    _ input: (Bool, Bool, Int, Bool)
) {
    let (isLoading, isLoadingMore, urlCount, hasError) = input
    let first = AudioDBSettingPresentation.listState(
        isLoading: isLoading,
        isLoadingMore: isLoadingMore,
        urlCount: urlCount,
        hasError: hasError
    )
    let second = AudioDBSettingPresentation.listState(
        isLoading: isLoading,
        isLoadingMore: isLoadingMore,
        urlCount: urlCount,
        hasError: hasError
    )
    #expect(first == second)
}

// MARK: - 加载更多指示器

/// 空列表下不显示底部转圈 —— 已在顶部显示首次加载指示。
@Test func loadingMoreIndicatorHiddenForEmptyList() {
    #expect(AudioDBSettingPresentation.shouldShowLoadingMoreIndicator(
        isLoadingMore: true,
        urlCount: 0
    ) == false)
}

@Test func loadingMoreIndicatorVisibleOnlyWithContentAndLoading() {
    #expect(AudioDBSettingPresentation.shouldShowLoadingMoreIndicator(
        isLoadingMore: true,
        urlCount: 10
    ))
    #expect(AudioDBSettingPresentation.shouldShowLoadingMoreIndicator(
        isLoadingMore: false,
        urlCount: 10
    ) == false)
}

// MARK: - 诊断链路

/// 诊断项缺失时显式标注 "nil"，比留空更利于排查。
@Test func diagnosticValuesFallBackToNilPlaceholder() {
    #expect(AudioDBSettingPresentation.diagnosticDisplayValue(nil) == "nil")
    #expect(AudioDBSettingPresentation.diagnosticDisplayValue("") == "")
    #expect(AudioDBSettingPresentation.diagnosticDisplayValue("/iCloud/com.app") == "/iCloud/com.app")
}

/// 仓库不可用时才展示诊断链路；可用时无需打扰用户。
@Test func diagnosticsOnlyShownWhenDiskUnavailable() {
    #expect(AudioDBSettingPresentation.shouldShowDiagnostics(diskAvailable: false))
    #expect(AudioDBSettingPresentation.shouldShowDiagnostics(diskAvailable: true) == false)
}
