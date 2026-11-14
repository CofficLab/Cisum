import Foundation
import OSLog

#if os(macOS)

/// 网络相关的Shell命令工具类
class ShellNetwork: SuperLog {
    static let emoji = "🌐"

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func pingCommand(_ host: String = "google.com") -> String {
        "ping -c 1 -W 3000 \(shellQuoted(host))"
    }

    static func normalizedPingCount(_ count: Int) -> Int {
        min(max(count, 1), 100)
    }

    static func pingDetailedCommand(_ host: String, count: Int = 4) -> String {
        "ping -c \(normalizedPingCount(count)) \(shellQuoted(host))"
    }

    static func downloadCommand(_ url: String, to output: String) -> String {
        "curl -L \(shellQuoted(url)) -o \(shellQuoted(output))"
    }

    static func curlCommand(_ url: String) -> String {
        "curl -s \(shellQuoted(url))"
    }

    static func headersCommand(_ url: String) -> String {
        "curl -I \(shellQuoted(url))"
    }

    static func normalizedPort(_ port: Int) -> Int? {
        (1...65535).contains(port) ? port : nil
    }

    static func testPortCommand(_ host: String, port: Int) -> String? {
        guard let port = normalizedPort(port) else { return nil }
        return "nc -z -w3 \(shellQuoted(host)) \(port)"
    }

    static func nslookupCommand(_ domain: String) -> String {
        "nslookup \(shellQuoted(domain))"
    }

    static func tracerouteCommand(_ host: String) -> String {
        "traceroute \(shellQuoted(host))"
    }

    static func httpStatusCommand(_ url: String) -> String {
        "curl -s -o /dev/null -w '%{http_code}' \(shellQuoted(url))"
    }

    /// 测试网络连接
    /// - Parameter host: 主机地址（默认为google.com）
    /// - Returns: 是否连接成功
    static func ping(_ host: String = "google.com") -> Bool {
        do {
            _ = try Shell.runSync(pingCommand(host))
            return true
        } catch {
            return false
        }
    }

    /// 获取详细的ping信息
    /// - Parameters:
    ///   - host: 主机地址
    ///   - count: ping次数（默认4次）
    /// - Returns: ping结果
    /// - Throws: 执行失败时抛出错误
    static func pingDetailed(_ host: String, count: Int = 4) throws -> String {
        try Shell.runSync(pingDetailedCommand(host, count: count))
    }

    /// 下载文件
    /// - Parameters:
    ///   - url: 下载链接
    ///   - output: 输出文件路径
    /// - Throws: 下载失败时抛出错误
    static func download(_ url: String, to output: String) throws {
        try Shell.runSync(downloadCommand(url, to: output))
    }

    /// 获取URL内容
    /// - Parameter url: URL地址
    /// - Returns: URL内容
    /// - Throws: 获取失败时抛出错误
    static func curl(_ url: String) throws -> String {
        try Shell.runSync(curlCommand(url))
    }

    /// 获取URL的HTTP头信息
    /// - Parameter url: URL地址
    /// - Returns: HTTP头信息
    /// - Throws: 获取失败时抛出错误
    static func getHeaders(_ url: String) throws -> String {
        try Shell.runSync(headersCommand(url))
    }

    /// 测试端口连接
    /// - Parameters:
    ///   - host: 主机地址
    ///   - port: 端口号
    /// - Returns: 端口是否开放
    static func testPort(_ host: String, port: Int) -> Bool {
        do {
            guard let command = testPortCommand(host, port: port) else { return false }
            _ = try Shell.runSync(command)
            return true
        } catch {
            return false
        }
    }

    /// 获取本机IP地址
    /// - Returns: IP地址数组
    static func getLocalIPs() -> [String] {
        do {
            let result = try Shell.runSync("ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}'")
            return result.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    /// 获取公网IP地址
    /// - Returns: 公网IP地址
    static func getPublicIP() -> String {
        do {
            return try Shell.runSync("curl -s ifconfig.me").trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return publicIPFailureMessage
        }
    }

    /// 获取网络接口状态
    /// - Returns: 网络接口状态
    static func getNetworkStatus() -> String {
        do {
            return try Shell.runSync("ifconfig | grep -E '^[a-z]|inet '")
        } catch {
            return error.localizedDescription
        }
    }

    /// 查看路由表
    /// - Returns: 路由表信息
    static func getRoutes() -> String {
        do {
            return try Shell.runSync("netstat -rn")
        } catch {
            return error.localizedDescription
        }
    }

    /// 查看网络连接
    /// - Returns: 网络连接信息
    static func getConnections() -> String {
        do {
            return try Shell.runSync("netstat -an")
        } catch {
            return error.localizedDescription
        }
    }

    /// DNS查询
    /// - Parameter domain: 域名
    /// - Returns: DNS查询结果
    /// - Throws: 查询失败时抛出错误
    static func nslookup(_ domain: String) throws -> String {
        try Shell.runSync(nslookupCommand(domain))
    }

    /// 追踪路由
    /// - Parameter host: 目标主机
    /// - Returns: 路由追踪结果
    /// - Throws: 追踪失败时抛出错误
    static func traceroute(_ host: String) throws -> String {
        try Shell.runSync(tracerouteCommand(host))
    }

    /// 获取WiFi信息
    /// - Returns: WiFi信息
    static func getWiFiInfo() -> String {
        do {
            return try Shell.runSync("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I")
        } catch {
            return error.localizedDescription
        }
    }

    /// 扫描WiFi网络
    /// - Returns: WiFi网络列表
    static func scanWiFi() -> String {
        do {
            return try Shell.runSync("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s")
        } catch {
            return error.localizedDescription
        }
    }

    /// 检查网站可访问性
    /// - Parameter url: 网站URL
    /// - Returns: HTTP状态码
    static func getHTTPStatus(_ url: String) -> Int {
        do {
            let result = try Shell.runSync(httpStatusCommand(url))
            return Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        } catch {
            return 0
        }
    }

    /// 测试网络速度（简单版本）
    /// - Returns: 下载速度测试结果
    static func speedTest() -> String {
        do {
            // 下载一个小文件来测试速度
            let result = try Shell.runSync("curl -w '%{speed_download}' -s -o /dev/null http://speedtest.wdc01.softlayer.com/downloads/test10.zip")
            let speed = Double(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            return String(format: "%.2f KB/s", speed / 1024)
        } catch {
            return speedTestFailureMessage
        }
    }

    static let publicIPFailureMessage = "Failed to get public IP"
    static let speedTestFailureMessage = "Speed test failed"
}

#endif
