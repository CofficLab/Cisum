import SwiftUI

// MARK: - Environment Key for Demo Mode

struct DemoModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var demoMode: Bool {
        get { self[DemoModeKey.self] }
        set { self[DemoModeKey.self] = newValue }
    }
}

// MARK: - View Extension for Demo Mode

extension View {
    func inDemoMode() -> some View {
        self.environment(\.demoMode, true)
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
