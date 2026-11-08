#if os(visionOS)
import FactoryCisum
import ProviderDevice
import Testing

/// `DeviceService` 在 visionOS 上的平台语义回归。
///
/// visionOS 没有「主屏幕」这一概念（显示尺寸由窗口 / 沉浸空间决定），
/// 也没有 iPad 形态。`DeviceService` 对这两种查询返回确定的零值 / false，
/// 而不是崩溃或 fallback 到 `UIScreen.main`（后者在 visionOS 上不可用）。
///
/// - Note: 仅在 visionOS 目标下编译与执行；在其他平台上整份文件被条件编译排除。
@MainActor
struct DeviceServiceVisionOSTests {
    @Test
    func isNotPadNorDesktopOnVisionOS() {
        let service = DeviceService()

        #expect(service.isMac == false)
        #expect(service.isPad == false)
    }

    @Test
    func primaryScreenSizeIsZeroBecauseVisionOSHasNoMainScreen() {
        let service = DeviceService()

        #expect(service.screenWidth == 0)
        #expect(service.screenHeight == 0)
    }

    @Test
    func exposesNonEmptySystemDescription() {
        let service = DeviceService()

        #expect(service.deviceModel.isEmpty == false)
        #expect(service.systemVersion.isEmpty == false)
    }
}
#endif
