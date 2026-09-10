import KernelCore

/// Docs-specific convenience accessors live beside the Docs provider so the
/// core package does not depend on this optional capability package.
public extension CisumKernelContainer {
    /// 文档视图提供器（关于 / 说明书条目集合）。
    var docs: (any DocsViewProviding)? {
        resolveProvider(DocsViewProviding.self)
    }

    /// 注册文档视图服务。
    ///
    /// - Throws: `CisumKernelError.providerAlreadyRegistered` 重复注册。
    func registerDocsService(_ docs: any DocsViewProviding) throws {
        try registerProvider(DocsViewProviding.self, docs)
    }
}
