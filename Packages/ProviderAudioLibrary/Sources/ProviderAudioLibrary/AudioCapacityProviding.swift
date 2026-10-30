import Foundation

/// 仓库容量准入的判定结果。
///
/// 判定只回答一件事：**这批文件能进几个**。调用方据此决定放行多少、丢弃多少，
/// 不必自己重算额度——额度的算法只存在于实现方一处。
public enum AudioCapacityAdmission: Sendable, Equatable {
    /// 全部放行。
    case admitted

    /// 部分放行：`allowedCount` 个文件可写入，其余被容量挡住。
    ///
    /// 只在「有文件被挡住」时使用；能全放行时用 `.admitted`。
    case partiallyAdmitted(allowedCount: Int)

    /// 全部挡住：一个文件都进不去。
    case rejected

    /// 实际可写入的文件数量。
    ///
    /// - Parameter requestedCount: 请求写入的数量。
    public func allowedCount(requestedCount: Int) -> Int {
        switch self {
        case .admitted: requestedCount
        case .partiallyAdmitted(let allowedCount): min(allowedCount, requestedCount)
        case .rejected: 0
        }
    }

    /// 本次判定是否拒绝了至少一个文件。
    ///
    /// 调用方据此决定要不要引导付费：`true` 说明撞上了容量上限。
    public var didReject: Bool {
        switch self {
        case .admitted: false
        case .partiallyAdmitted: true
        case .rejected: true
        }
    }
}

/// 仓库容量准入能力协议。
///
/// ## 为什么是「能力」而不是散落的判断
///
/// 仓库有多个写入入口（拖放到主窗口、仓库视图的文件选择器、仓库视图的拖放），
/// 它们都写同一个目录。容量限制如果分散在这些入口里各判一次，迟早会漏掉一个——
/// 漏掉的那个就成了绕过路径，限制形同虚设。
///
/// 这一层把「能不能写」收敛成**唯一判定**：所有写入入口在复制文件之前
/// 都先问一次「这批文件能进几个」，判定规则只存在于实现方一处。
///
/// ## 判定依据
///
/// 实现方持有两样东西：
/// 1. **容量真值**——仓库里现在有多少文件（数据层知道）；
/// 2. **权益**——当前用户是不是付费用户（商店层知道）。
///
/// 免费用户有上限，付费用户没有。实现方因此能把「计数」与「权益」合成
/// 一个结论，调用方不必自己拼装这两样东西。
///
/// ## 线程语义
/// 主线程语义（`@MainActor`），与 `AudioLibraryProviding` 一致。
@MainActor
public protocol AudioCapacityProviding: AnyObject, Sendable {
    /// 免费用户可持有的最大文件数量。
    ///
    /// 付费用户不受此限制。
    var freeTierFileLimit: Int { get }

    /// 当前用户是否不受容量限制（付费用户）。
    var isCapacityUnlimited: Bool { get }

    /// 当前订阅档位的显示名。
    ///
    /// 限额提示要告诉用户「你现在是什么档位」——这是引导付费的前提：
    /// 用户得先知道自己差在哪一档。
    var tierDisplayName: String { get }

    /// 判定一批文件能否写入仓库。
    ///
    /// - Parameters:
    ///   - requestedCount: 请求写入的文件数量。
    ///   - reservedCount: 已被**进行中的写入操作**占用的槽位数量。
    ///     复制是异步的：文件真正落盘前，操作就已「占了位」。不计入这些槽位，
    ///     连续两次拖放都会读到同一个仓库计数，从而双双放行、最终超限。
    ///     只有知道自己在排队副本的操作方才有这个信息，因此由调用方传入。
    /// - Returns: 判定结果，含实际可写入的数量。
    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission
}

public extension AudioCapacityProviding {
    /// 未注册容量能力的实现方默认「不限容量」。
    ///
    /// 取「放行」而非「拒绝」作为默认值：容量能力缺失是装配问题，不该让
    /// 用户的文件凭空进不去。真正的限制由实现了本协议的数据层负责。
    var freeTierFileLimit: Int { AudioPluginInfo.maxAudioCount }

    var isCapacityUnlimited: Bool { true }

    var tierDisplayName: String { "Free version" }

    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission {
        .admitted
    }
}
