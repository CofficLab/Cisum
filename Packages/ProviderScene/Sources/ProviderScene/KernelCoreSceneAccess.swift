import KernelCore

/// Scene-specific convenience accessors live beside the Scene provider so the
/// core package does not depend on this optional capability package.
public extension CisumKernelContainer {
    var scene: (any SceneProviding)? {
        resolveProvider(SceneProviding.self)
    }

    /// 注册场景服务。
    ///
    /// - Throws: `CisumKernelError.providerAlreadyRegistered` 重复注册。
    func registerSceneService(_ scene: any SceneProviding) throws {
        try registerProvider(SceneProviding.self, scene)
    }
}
