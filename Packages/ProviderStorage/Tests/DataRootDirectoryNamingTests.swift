import Foundation
import Testing
@testable import CisumProviderStorage

/// 数据根目录命名规则的契约测试。
///
/// 这条规则决定了**所有**插件数据目录的父目录。改错了不会立刻报错——
/// 插件只是把数据写到一个没人去看的目录里，用户表现为「数据凭空消失」。
/// 因此这里锁死规则本身，并锁死「历史实现与共享定义必须一致」。
///
/// ## 为什么要有「一致性」断言
///
/// 命名规则曾散落在多个地方各自实现（`StorageProvider`、`PluginFileLog`、
/// `PluginAudioCopy`、通用设置页各抄一份）。收敛到 `DataRootDirectoryNaming`
/// 后，必须保证**收敛前后算出的目录名完全相同**——否则等于给用户搬了一次家，
/// 所有插件的历史数据都留在了旧目录。
@Test func dataRootDirectoryNameFollowsDebugAndMajorVersion() {
    #expect(DataRootDirectoryNaming.directoryName(isDebug: true, majorVersion: 4) == "db_debug_v4")
    #expect(DataRootDirectoryNaming.directoryName(isDebug: false, majorVersion: 4) == "db_production_v4")
    #expect(DataRootDirectoryNaming.directoryName(isDebug: true, majorVersion: 1) == "db_debug_v1")
}

/// 版本号解析：取主版本号，无法解析时回退 1。
@Test func majorVersionParsingFallsBackToOne() {
    #expect(DataRootDirectoryNaming.majorVersion(from: "4.4.11") == 4)
    #expect(DataRootDirectoryNaming.majorVersion(from: "5") == 5)
    #expect(DataRootDirectoryNaming.majorVersion(from: "") == 1)
    #expect(DataRootDirectoryNaming.majorVersion(from: "not-a-version") == 1)
}

/// 收敛后的共享定义必须与**重构前各处的实现**逐字节一致。
///
/// 这里的期望值是硬编码的字符串字面量，而不是拿 `StorageProvider` 的
/// 静态方法来对照——那样会变成「用新实现验证新实现」，一旦两边一起
/// 漂移，测试依然通过。这里刻意锁死字面量。
@Test func sharedNamingMatchesHistoricalImplementations() {
    // StorageProvider 旧实现：environment = debug ? "debug" : "production"
    #expect(DataRootDirectoryNaming.directoryName(isDebug: true, majorVersion: 4)
            == "db_" + "debug" + "_v" + "4")
    #expect(DataRootDirectoryNaming.directoryName(isDebug: false, majorVersion: 4)
            == "db_" + "production" + "_v" + "4")

    // PluginFileLog / PluginAudioCopy 旧实现：同样是 db_<env>_v<major>
    #expect(DataRootDirectoryNaming.directoryName(isDebug: true, versionString: "4.4.11")
            == "db_debug_v4")
    #expect(DataRootDirectoryNaming.directoryName(isDebug: false, versionString: "4.4.11")
            == "db_production_v4")
}

/// 当前进程的目录名必须落在 `db_*` 命名空间内，且当前构建类型与环境匹配。
@Test func currentDirectoryNameMatchesCurrentBuild() {
    let name = DataRootDirectoryNaming.directoryName()

    #expect(name.hasPrefix("db_"))
    if DataRootDirectoryNaming.isDebugBuild {
        #expect(name.hasPrefix("db_debug_v"))
    } else {
        #expect(name.hasPrefix("db_production_v"))
    }
}
