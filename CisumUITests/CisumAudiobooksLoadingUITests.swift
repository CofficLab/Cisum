import XCTest

/// 场景切换时"正在读取有声书仓库"状态的回归测试。
///
/// 复现问题：从音乐场景切换到有声书场景时，"正在读取有声书仓库"一直显示，
/// 长时间不消失。这意味着 `isLoading` 一直为 `true`，数据加载流程卡住了。
final class CisumAudiobooksLoadingUITests: CisumUITestBase {
    
    /// 测试场景：从音乐场景切换到有声书场景。
    /// 预期：有声书场景应该正常加载，不会一直显示"正在读取有声书仓库"。
    func testSwitchingFromMusicToAudiobooksDoesNotStallOnLoading() throws {
        #if os(macOS)
        // 确保从音乐场景开始
        try ensureMusicScene()
        XCTAssertTrue(element(identifier: "cisum.scene.music").waitForExistence(timeout: 10), "音乐场景未出现")
        
        // 切换到有声书场景
        try ensureAudiobooksScene()
        let audiobooksScene = element(identifier: "cisum.scene.audiobooks")
        XCTAssertTrue(audiobooksScene.waitForExistence(timeout: 10), "有声书场景未出现")
        
        // 等待加载完成：要么显示内容（表头/书卡），要么显示空状态
        // "正在读取有声书仓库"不应该持续超过 10 秒
        let loadingIndicator = element(anyLabelOf: ["Reading book repository", "正在读取有声书仓库"])
        let header = element(labelBeginsWith: ["Total", "共"])
        let emptyState = element(containing: "Drop audiobook folders here to add them").exists
            || element(containing: "将有声书文件夹拖到这里可添加").exists
            || element(containing: "Audiobook repository is empty").exists
            || element(containing: "有声书仓库为空").exists
            || element(containing: "Repository is empty").exists
            || element(containing: "仓库为空").exists
        
        // 等待加载状态消失或内容出现
        let startTime = Date()
        let timeout: TimeInterval = 15
        
        while Date().timeIntervalSince(startTime) < timeout {
            if !loadingIndicator.exists || header.exists || emptyState {
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // 验证：加载状态应该消失，或者内容/空状态应该出现
        if loadingIndicator.exists {
            // 如果还在显示加载状态，检查是否已经超过合理时间
            let elapsed = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(elapsed, timeout, "有声书场景加载状态持续超过 \(timeout) 秒，可能卡在 waitForInitialSync()")
        }
        
        // 最终验证：内容区应该呈现（表头、书卡或空状态）
        let contentVisible = header.exists || emptyState
        XCTAssertTrue(contentVisible, "有声书场景内容区未呈现：既无表头统计，也无空状态")
        #else
        throw XCTSkip("场景切换测试仅 macOS 支持")
        #endif
    }
    
    /// 测试场景：快速在音乐和有声书场景之间切换。
    /// 预期：场景应该正常切换，不会卡死。
    func testRapidSceneSwitchingDoesNotStall() throws {
        #if os(macOS)
        // 快速切换多次
        for _ in 0..<3 {
            try ensureMusicScene()
            XCTAssertTrue(element(identifier: "cisum.scene.music").waitForExistence(timeout: 5), "音乐场景未出现")
            
            try ensureAudiobooksScene()
            XCTAssertTrue(element(identifier: "cisum.scene.audiobooks").waitForExistence(timeout: 5), "有声书场景未出现")
        }
        
        // 最终验证：有声书场景应该正常显示
        let header = element(labelBeginsWith: ["Total", "共"])
        let emptyState = element(containing: "Drop audiobook folders here to add them").exists
            || element(containing: "将有声书文件夹拖到这里可添加").exists
            || element(containing: "Audiobook repository is empty").exists
            || element(containing: "有声书仓库为空").exists
            || element(containing: "Repository is empty").exists
            || element(containing: "仓库为空").exists
        
        // 等待加载完成
        let loadingIndicator = element(anyLabelOf: ["Reading book repository", "正在读取有声书仓库"])
        let startTime = Date()
        let timeout: TimeInterval = 10
        
        while Date().timeIntervalSince(startTime) < timeout {
            if !loadingIndicator.exists || header.exists || emptyState {
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        let contentVisible = header.exists || emptyState
        XCTAssertTrue(contentVisible, "快速切换后有声书场景内容区未呈现")
        #else
        throw XCTSkip("场景切换测试仅 macOS 支持")
        #endif
    }
}
