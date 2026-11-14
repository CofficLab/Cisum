import SwiftUI

// MARK: - Avatar Sizes
public enum AvatarSize {
    /// 小尺寸 (24x24)
    case small
    /// 中等尺寸 (32x32)
    case medium
    /// 大尺寸 (40x40)
    case large
    /// 特大尺寸 (56x56)
    case xlarge
    /// 自定义正方形尺寸
    case custom(CGFloat)
    /// 自定义长方形尺寸
    case rectangle(width: CGFloat, height: CGFloat)
    
    var size: CGSize {
        switch self {
        case .small: CGSize(width: 24, height: 24)
        case .medium: CGSize(width: 32, height: 32)
        case .large: CGSize(width: 40, height: 40)
        case .xlarge: CGSize(width: 56, height: 56)
        case .custom(let size): CGSize(width: size, height: size)
        case .rectangle(let width, let height): CGSize(width: width, height: height)
        }
    }
}

