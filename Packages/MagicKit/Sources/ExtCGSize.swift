import Foundation

/// CGSize 类型的扩展，提供常用设备尺寸和实用方法
///
/// 这个扩展为CGSize类型添加了常用iOS和macOS设备的物理像素尺寸常量、
/// 逻辑点尺寸常量以及预览缩放变体，便于在开发中快速引用和判断尺寸特性。
///
/// ## 尺寸类型说明:
/// - **物理像素尺寸 (Physical Pixels)**: 设备屏幕的实际像素数，用于图像处理和高精度布局
/// - **逻辑点尺寸 (Logical Points)**: SwiftUI 布局使用的点坐标，用于 UI 设计和自适应布局
/// - **预览缩放变体 (Preview Scaling)**: 用于预览和调试的小尺寸版本
///
/// ## 使用示例:
/// ```swift
/// // 物理像素尺寸（图像处理、高精度布局）
/// let physicalSize = CGSize.iPhone
/// print(physicalSize.description) // "1170x2532"
///
/// // 逻辑点尺寸（SwiftUI 布局、UI 设计）
/// let pointSize = CGSize.iPhonePoint
/// print(pointSize.description) // "390x844"
///
/// // 预览缩放尺寸（预览、调试）
/// let previewSize = CGSize.iPhone_50Percent
/// print(previewSize.description) // "195x422"
///
/// // 尺寸判断
/// let isSquare = CGSize(width: 100, height: 100).isSquare // true
/// let isPortrait = CGSize(width: 390, height: 844).isPortrait // true
/// ```
public extension CGSize {

    // MARK: - Computed Properties (计算属性)

    /// 判断尺寸是否为正方形
    ///
    /// 当宽度等于高度时返回 true
    /// ```swift
    /// CGSize(width: 100, height: 100).isSquare // true
    /// CGSize.iPhone.isSquare // false
    /// ```
    var isSquare: Bool {
        width == height
    }

    /// 判断是否为竖屏布局（宽度小于高度）
    ///
    /// ```swift
    /// CGSize.iPhone.isPortrait // true
    /// CGSize.iPhone.landscape().isPortrait // false
    /// ```
    var isPortrait: Bool {
        width < height
    }

    /// 判断是否为横屏布局（宽度大于高度）
    ///
    /// ```swift
    /// CGSize.iPhone.isLandscape // false
    /// CGSize.iPhone.landscape().isLandscape // true
    /// ```
    var isLandscape: Bool {
        width > height
    }

    /// 获取尺寸的字符串描述
    ///
    /// 返回格式为 "宽度x高度" 的字符串
    /// ```swift
    /// CGSize.iPhone.description // "1170x2532"
    /// ```
    var description: String {
        "\(width.descriptionComponent)x\(height.descriptionComponent)"
    }

    /// 转换为横屏布局
    ///
    /// ```swift
    /// let portrait = CGSize(width: 390, height: 844)
    /// let landscape = portrait.landscape() // CGSize(width: 844, height: 390)
    /// ```
    func landscape() -> CGSize {
        CGSize(width: height, height: width)
    }

    // MARK: - Physical Pixel Sizes (物理像素尺寸)
    // MARK: iPhone

    /// iPhone SE 的物理像素尺寸 (750x1334)
    static let iPhoneSE = CGSize(width: 750, height: 1334)

    /// iPhone 4.7英寸 的物理像素尺寸 (750x1334)，适用于 iPhone 6/7/8
    static let iPhone47 = CGSize(width: 750, height: 1334)

    /// iPhone 5.4英寸 mini 的物理像素尺寸 (1080x2340)，适用于 iPhone 12/13/14 mini
    static let iPhoneMini = CGSize(width: 1080, height: 2340)

    /// iPhone 5.8英寸 的物理像素尺寸 (1125x2436)，适用于 iPhone X/XS/11 Pro
    static let iPhone58 = CGSize(width: 1125, height: 2436)

    /// iPhone 6.1英寸 LCD 的物理像素尺寸 (828x1792)，适用于 iPhone XR/11
    static let iPhone61LCD = CGSize(width: 828, height: 1792)

    /// 标准iPhone 的物理像素尺寸 (1170x2532)，适用于 iPhone 12/13/14
    static let iPhone = CGSize(width: 1170, height: 2532)

    /// iPhone 6.1英寸 OLED 的物理像素尺寸 (1179x2556)，适用于 iPhone 12/13/14 Pro
    static let iPhonePro = CGSize(width: 1179, height: 2556)

    /// iPhone 5.5英寸 Plus 的物理像素尺寸 (1242x2208)，适用于 iPhone 6/7/8 Plus
    static let iPhone55 = CGSize(width: 1242, height: 2208)

    /// iPhone 6.5英寸 的物理像素尺寸 (1242x2688)，适用于 iPhone XS Max、11 Pro Max
    static let iPhone65 = CGSize(width: 1242, height: 2688)

    /// iPhone Plus 的物理像素尺寸 (1284x2778)，适用于 iPhone Plus 系列
    static let iPhonePlus = CGSize(width: 1284, height: 2778)

    /// iPhone 6.9英寸 的物理像素尺寸 (1290x2796)，适用于 iPhone 14/15 Pro Max
    static let iPhone69 = CGSize(width: 1290, height: 2796)

    /// iPhone Max 的物理像素尺寸 (1290x2796)，适用于 iPhone Pro Max 系列
    static let iPhoneMax = CGSize(width: 1290, height: 2796)

    // MARK: iPad

    /// iPad Mini 的物理像素尺寸 (1488x2266)
    static let iPadMini = CGSize(width: 1488, height: 2266)

    /// 标准iPad 的物理像素尺寸 (1640x2360)
    static let iPad = CGSize(width: 1640, height: 2360)

    /// iPad Pro 11英寸 的物理像素尺寸 (1668x2388)
    static let iPadPro11 = CGSize(width: 1668, height: 2388)

    /// iPad Pro 12.9英寸 的物理像素尺寸 (2048x2732)
    static let iPadPro12 = CGSize(width: 2048, height: 2732)

    // MARK: MacBook

    /// MacBook Air 13英寸 的物理像素尺寸 (2560x1600)
    static let macBookAir13 = CGSize(width: 2560, height: 1600)

    /// MacBook Pro 13英寸 的物理像素尺寸 (2560x1600)
    static let macBookPro13 = CGSize(width: 2560, height: 1600)

    /// MacBook Pro 14英寸 的物理像素尺寸 (3024x1964)
    static let macBookPro14 = CGSize(width: 3024, height: 1964)

    /// MacBook Pro 16英寸 的物理像素尺寸 (3456x2234)
    static let macBookPro16 = CGSize(width: 3456, height: 2234)

    /// MacBook 13英寸 的物理像素尺寸 (2560x1600)
    static let macBook13 = CGSize(width: 2560, height: 1600)

    // MARK: iMac

    /// iMac 24英寸 M1/M3/M4 的物理像素尺寸 (4480x2520)
    static let iMac24 = CGSize(width: 4480, height: 2520)

    /// iMac 27英寸 Retina 的物理像素尺寸 (5120x2880)
    static let iMac27 = CGSize(width: 5120, height: 2880)

    // MARK: External Displays (外接显示器)

    /// Apple Studio Display 27英寸 的物理像素尺寸 (5120x2880)
    static let studioDisplay = CGSize(width: 5120, height: 2880)

    /// Apple Pro Display XDR 32英寸 的物理像素尺寸 (6016x3384)
    static let proDisplayXDR = CGSize(width: 6016, height: 3384)

    /// 标准Mac窗口的参考尺寸 (1024x768)
    static let mac = CGSize(width: 1024, height: 768)

    // MARK: - Logical Point Sizes (逻辑点尺寸 - 用于 SwiftUI 布局)
    // MARK: iPhone

    /// iPhone SE 的逻辑点尺寸 (375x667)
    static let iPhoneSEPoint = CGSize(width: 375, height: 667)

    /// 标准iPhone 的逻辑点尺寸 (390x844)
    static let iPhonePoint = CGSize(width: 390, height: 844)

    /// iPhone Plus 的逻辑点尺寸 (428x926)
    static let iPhonePlusPoint = CGSize(width: 428, height: 926)

    /// iPhone Max 的逻辑点尺寸 (430x932)
    static let iPhoneMaxPoint = CGSize(width: 430, height: 932)

    // MARK: iPad

    /// iPad Mini 的逻辑点尺寸 (744x1133)
    static let iPadMiniPoint = CGSize(width: 744, height: 1133)

    /// 标准iPad 的逻辑点尺寸 (820x1180)
    static let iPadPoint = CGSize(width: 820, height: 1180)

    /// iPad Pro 11英寸 的逻辑点尺寸 (834x1194)
    static let iPadPro11Point = CGSize(width: 834, height: 1194)

    /// iPad Pro 12.9英寸 的逻辑点尺寸 (1024x1366)
    static let iPadPro12Point = CGSize(width: 1024, height: 1366)

    // MARK: MacBook

    /// MacBook 13英寸 的逻辑点尺寸 (2550x1650)
    static let macBook13Point = CGSize(width: 2550, height: 1650)

    // MARK: iMac

    /// iMac 27英寸 的逻辑点尺寸 (5120x2890)
    static let iMac27Point = CGSize(width: 5120, height: 2890)

    // MARK: - Preview Scaling Variants (预览缩放变体 - 用于预览和调试)
    // MARK: 50% Scale (半尺寸)

    /// iPhone SE 50% 预览尺寸 (188x334)
    static let iPhoneSE_50Percent = CGSize(width: 188, height: 334)

    /// iPhone 50% 预览尺寸 (195x422)
    static let iPhone_50Percent = CGSize(width: 195, height: 422)

    /// iPhone Plus 50% 预览尺寸 (214x463)
    static let iPhonePlus_50Percent = CGSize(width: 214, height: 463)

    /// iPhone Max 50% 预览尺寸 (215x466)
    static let iPhoneMax_50Percent = CGSize(width: 215, height: 466)

    /// iPad Mini 50% 预览尺寸 (372x567)
    static let iPadMini_50Percent = CGSize(width: 372, height: 567)

    /// iPad 50% 预览尺寸 (410x590)
    static let iPad_50Percent = CGSize(width: 410, height: 590)

    /// iPad Pro 11英寸 50% 预览尺寸 (417x597)
    static let iPadPro11_50Percent = CGSize(width: 417, height: 597)

    /// iPad Pro 12.9英寸 50% 预览尺寸 (512x683)
    static let iPadPro12_50Percent = CGSize(width: 512, height: 683)

    /// Mac 50% 预览尺寸 (512x384)
    static let mac_50Percent = CGSize(width: 512, height: 384)

    // MARK: MacBook Preview Variants

    /// MacBook 13英寸 50% 预览尺寸 (1280x800)
    static let macBook13_50Percent = CGSize(width: 1280, height: 800)

    /// MacBook 13英寸 20% 预览尺寸 (512x320)
    static let macBook13_20Percent = CGSize(width: 512, height: 320)

    /// MacBook 13英寸 10% 预览尺寸 (256x160)
    static let macBook13_10Percent = CGSize(width: 256, height: 160)

    /// MacBook 13英寸 50% 逻辑点预览尺寸 (1275x825)
    static let macBook13_50PercentPoint = CGSize(width: 1275, height: 825)

    // MARK: iMac Preview Variants

    /// iMac 27英寸 50% 预览尺寸 (2560x1445)
    static let iMac27_50Percent = CGSize(width: 2560, height: 1445)

    /// iMac 27英寸 20% 预览尺寸 (1024x576)
    static let iMac27_20Percent = CGSize(width: 1024, height: 576)

    /// iMac 27英寸 10% 预览尺寸 (512x288)
    static let iMac27_10Percent = CGSize(width: 512, height: 288)

    /// iMac 27英寸 预览尺寸 (512x289)，适合快速预览
    static let iMac27Preview = CGSize(width: 512, height: 289)

    /// iMac 27英寸 中等预览尺寸 (1024x578)，适合开发调试
    static let iMac27Medium = CGSize(width: 1024, height: 578)
}

private extension CGFloat {
    var descriptionComponent: Int {
        guard isFinite else { return 0 }
        return Int(self)
    }
}
