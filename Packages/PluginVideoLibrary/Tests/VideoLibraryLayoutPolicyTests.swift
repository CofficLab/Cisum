import Foundation
import Testing
@testable import PluginVideoLibrary

/// 视频库响应式布局与时间格式化的行为测试。
struct VideoLibraryLayoutPolicyTests {
    @Test("按宽度划分宽 / 中 / 紧凑三档")
    func layoutBreakpoints() {
        #expect(VideoLibraryLayoutPolicy.layout(forWidth: 399) == .compact)
        #expect(VideoLibraryLayoutPolicy.layout(forWidth: 400) == .compact)
        #expect(VideoLibraryLayoutPolicy.layout(forWidth: 659) == .compact)
        #expect(VideoLibraryLayoutPolicy.layout(forWidth: 660) == .medium)
        #expect(VideoLibraryLayoutPolicy.layout(forWidth: 1079) == .medium)
        #expect(VideoLibraryLayoutPolicy.layout(forWidth: 1080) == .wide)
        #expect(VideoLibraryLayoutPolicy.layout(forWidth: 1180) == .wide)
    }

    @Test("侧栏常驻于中 / 宽布局，检查器列仅宽布局常驻")
    func columnVisibility() {
        #expect(!VideoLibraryLayoutPolicy.showsSidebar(.compact))
        #expect(VideoLibraryLayoutPolicy.showsSidebar(.medium))
        #expect(VideoLibraryLayoutPolicy.showsSidebar(.wide))

        #expect(!VideoLibraryLayoutPolicy.showsInspectorColumn(.compact))
        #expect(!VideoLibraryLayoutPolicy.showsInspectorColumn(.medium))
        #expect(VideoLibraryLayoutPolicy.showsInspectorColumn(.wide))
    }

    @Test("时长格式化为 m:ss 或 h:mm:ss")
    func timeFormatting() {
        #expect(VideoTimeFormatting.string(from: 0) == "0:00")
        #expect(VideoTimeFormatting.string(from: 65) == "1:05")
        #expect(VideoTimeFormatting.string(from: 3661) == "1:01:01")
    }
}
