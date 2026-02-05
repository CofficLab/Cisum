import MagicAlert
import MagicKit
import SwiftUI

// MARK: - Preview Size Presets

/// 预览尺寸预设
struct PreviewSize: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let size: CGSize

    /// 所有可用的预设尺寸
    /// 在这里添加或删除尺寸即可，修改后需重新打开预览生效
    static let allCases: [PreviewSize] = [
        PreviewSize("500 × 700"),
        PreviewSize("500 × 800"),
        PreviewSize("500 × 1000"),
        PreviewSize("600 × 900"),
        PreviewSize("800 × 1000"),
        PreviewSize("1000 × 1200"),
    ]

    /// 默认尺寸
    static let `default` = PreviewSize("600 × 900")

    /// 从尺寸字符串创建预设（如 "500 × 800"）
    init(_ name: String) {
        self.name = name
        let components = name.split(separator: "×").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1]) else {
            self.size = CGSize(width: 600, height: 900) // 默认尺寸
            return
        }
        self.size = CGSize(width: width, height: height)
    }

    /// 直接指定宽高
    init(width: Double, height: Double) {
        self.name = "\(Int(width)) × \(Int(height))"
        self.size = CGSize(width: width, height: height)
    }

    /// Equatable 实现（仅比较尺寸）
    static func == (lhs: PreviewSize, rhs: PreviewSize) -> Bool {
        lhs.size == rhs.size
    }

    private static let userDefaultsKey = "previewSizePreset"

    /// 保存用户选择的预设尺寸
    static func save(_ preset: PreviewSize) {
        UserDefaults.standard.set(preset.name, forKey: userDefaultsKey)
    }

    /// 加载用户选择的预设尺寸
    static func load() -> PreviewSize {
        let savedName = UserDefaults.standard.string(forKey: userDefaultsKey)
        return allCases.first { $0.name == savedName } ?? `default`
    }
}

// MARK: - Preview Size Toolbar

/// 预览尺寸选择工具栏
private struct PreviewSizeToolbar: View {
    @State private var selectedSizeName: String = PreviewSize.load().name

    var body: some View {
        Picker("", selection: $selectedSizeName) {
            ForEach(PreviewSize.allCases) { size in
                Text(size.name).tag(size.name)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 120)
        .onChange(of: selectedSizeName) { _, newName in
            if let size = PreviewSize.allCases.first(where: { $0.name == newName }) {
                PreviewSize.save(size)
            }
        }
    }
}

// MARK: - View Extension for Preview Mode

extension View {
    /// 设置预览模式（自动应用保存的尺寸并显示尺寸选择工具栏）
    /// - Returns: 启用预览模式的视图
    func withDebugBar() -> some View {
        let size = PreviewSize.load().size
        return DynamicPreviewSizingView(content: self, size: size)
    }
}

// MARK: - Dynamic Preview Sizing View

/// 预览尺寸容器视图
@MainActor
private struct DynamicPreviewSizingView<Content: View>: View {
    let content: Content
    let size: CGSize

    init(content: Content, size: CGSize) {
        self.content = content
        self.size = size
    }

    var body: some View {
        #if os(macOS)
            content
                .frame(width: size.width, height: size.height)
                .toolbar(content: {
                    PreviewSizeToolbar()
                })

        #else
            // iOS 平台直接返回原内容
            content
        #endif
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
