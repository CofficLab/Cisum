import Foundation
import Testing
@testable import MagicKit

/// `DeterministicWait` 的行为契约。
///
/// 这些用例本身就是确定性的证据：它们验证「等待」在条件成立时**立即**
/// 返回、在条件不成立时**按预算**退出，而不是靠固定 sleep 硬撑。
@Suite("DeterministicWait")
struct DeterministicWaitTests {
    /// 条件已成立时立即返回，不消耗整个预算。
    @Test func returnsImmediatelyWhenConditionAlreadyHolds() async {
        let start = Date()
        let satisfied = await DeterministicWait.until("恒真", timeout: 10) { true }
        let elapsed = Date().timeIntervalSince(start)

        #expect(satisfied)
        #expect(elapsed < 1, "条件已成立却等待了 \(elapsed)s")
    }

    /// 条件在若干轮轮询后成立时，等待随即结束。
    @Test func returnsWhenConditionHoldsAfterSomePolling() async {
        var attempts = 0
        let satisfied = await DeterministicWait.until(
            "第三次成立",
            timeout: 5,
            pollInterval: 0.01
        ) {
            attempts += 1
            return attempts >= 3
        }

        #expect(satisfied)
        #expect(attempts >= 3)
    }

    /// 条件始终不成立时，按预算退出并返回 `false`。
    @Test func givesUpAfterTimeout() async {
        let start = Date()
        let satisfied = await DeterministicWait.until(
            "恒假",
            timeout: 0.3,
            pollInterval: 0.02
        ) { false }
        let elapsed = Date().timeIntervalSince(start)

        #expect(!satisfied)
        #expect(elapsed >= 0.3, "提前退出了：只等了 \(elapsed)s")
    }

    /// 超时会触发回调，且回调拿到可诊断的描述。
    @Test func reportsTimeoutWithDescription() async {
        var reported: String?
        let satisfied = await DeterministicWait.expect(
            "库存应变为 3",
            timeout: 0.2,
            pollInterval: 0.02,
            onTimeout: { reported = $0 }
        ) { false }

        #expect(!satisfied)
        let message = try? #require(reported)
        #expect(message?.contains("库存应变为 3") == true)
    }

    /// 条件成立时不应触发超时回调。
    @Test func doesNotReportWhenConditionHolds() async {
        var reported: String?
        let satisfied = await DeterministicWait.expect(
            "恒真",
            timeout: 1,
            onTimeout: { reported = $0 }
        ) { true }

        #expect(satisfied)
        #expect(reported == nil)
    }

    /// 预算与机器速度解耦：预算由**时间**给出，而非固定轮数。
    ///
    /// 慢机上单次轮询更慢，但只要总预算够，结论就一致——这正是
    /// 「按墙钟预算」相较「固定轮数」的价值。
    @Test func budgetIsWallClockBasedRatherThanIterationBased() async {
        var attempts = 0
        let start = Date()
        let satisfied = await DeterministicWait.until(
            "耗时条件",
            timeout: 0.5,
            pollInterval: 0.05
        ) {
            attempts += 1
            return false
        }
        let elapsed = Date().timeIntervalSince(start)

        #expect(!satisfied)
        // 预算内至少轮询了若干次，但**不依赖**具体次数——次数随机器速度浮动。
        #expect(attempts >= 2, "轮询次数过少：\(attempts)")
        #expect(elapsed < 3, "超出预算太多：\(elapsed)s")
    }
}
