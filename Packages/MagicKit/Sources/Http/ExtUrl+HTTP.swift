import Foundation
import OSLog

/// URL 的 HTTP 便捷扩展
public extension URL {
    /// 创建一个 HttpClient，可选设置缓存有效期（秒）
    ///
    /// 用法示例：
    /// ```swift
    /// let url = URL(string: "https://httpbin.org/get")!
    /// let client = url.httpClient(cacheMaxAge: 30) // GET 缓存 30 秒
    /// let text = try await client.get()
    /// ```
    /// - Parameter cacheMaxAge: 缓存有效期（秒），<=0 表示禁用缓存
    /// - Returns: HttpClient 实例
    func httpClient(cacheMaxAge: TimeInterval = 0) -> HttpClient {
        if cacheMaxAge > 0 {
            return HttpClient(url: self, cacheMaxAge: cacheMaxAge)
        } else {
            return HttpClient(url: self)
        }
    }

    // MARK: - GET
    /// 便捷 GET 请求
    ///
    /// 用法示例：
    /// ```swift
    /// let url = URL(string: "https://httpbin.org/get")!
    /// // 简单 GET
    /// let text = try await url.httpGet()
    /// 
    /// // 带缓存（10 秒）与自定义 Header
    /// let text2 = try await url.httpGet(
    ///     headers: ["Accept": "application/json"],
    ///     timeout: 15,
    ///     cacheMaxAge: 10
    /// )
    /// 
    /// // 带 Token 的 GET
    /// let text3 = try await url.httpGet(token: "your_token")
    /// ```
    /// - Parameters:
    ///   - headers: 自定义请求头；若传入则覆盖默认请求头
    ///   - timeout: 超时（秒）。传入 nil 则使用默认值
    ///   - cacheMaxAge: 缓存有效期（秒）。仅对 GET 生效
    ///   - token: 可选 Bearer Token，会写入 Authorization 头
    /// - Returns: 响应字符串
    func httpGet(headers: [String:String]? = nil,
                 timeout: TimeInterval? = nil,
                 cacheMaxAge: TimeInterval = 0,
                 token: String? = nil) async throws -> String {
        var client = self.httpClient(cacheMaxAge: cacheMaxAge)
        if let headers { client = client.withHeaders(headers) }
        if let token { client = client.withToken(token) }
        if let timeout { client = client.withTimeout(timeout) }
        return try await client.get()
    }

    /// 便捷 GET 请求，返回 Data 与 HTTPURLResponse
    ///
    /// 用法示例：
    /// ```swift
    /// let url = URL(string: "https://httpbin.org/get")!
    /// let (data, resp) = try await url.httpGetData(cacheMaxAge: 5)
    /// print(resp.statusCode)
    /// ```
    func httpGetData(headers: [String:String]? = nil,
                     timeout: TimeInterval? = nil,
                     cacheMaxAge: TimeInterval = 0,
                     token: String? = nil) async throws -> (Data, HTTPURLResponse) {
        var client = self.httpClient(cacheMaxAge: cacheMaxAge)
        if let headers { client = client.withHeaders(headers) }
        if let token { client = client.withToken(token) }
        if let timeout { client = client.withTimeout(timeout) }
        return try await client.getDataAndResponse()
    }

    // MARK: - Cache Utilities
    /// 打开 HttpClient 的缓存目录（与 URL 无关，仅作便捷入口）
    ///
    /// 用法示例：
    /// ```swift
    /// let url = URL(string: "https://httpbin.org/get")!
    /// url.openHttpCacheDirectory() // 在 Finder 打开缓存目录
    /// ```
    func openHttpCacheDirectory() {
        HttpClient.openCacheDirectory()
    }

    // MARK: - POST
    /// 便捷 POST 请求
    ///
    /// 用法示例：
    /// ```swift
    /// let url = URL(string: "https://httpbin.org/post")!
    /// let resp = try await url.httpPost(
    ///     body: ["name": "Magic", "age": 1],
    ///     headers: ["Content-Type": "application/json"],
    ///     timeout: 10,
    ///     token: "your_token"
    /// )
    /// ```
    /// - Parameters:
    ///   - body: JSON Body
    ///   - headers: 自定义请求头；若传入则覆盖默认请求头
    ///   - timeout: 超时（秒）。传入 nil 则使用默认值
    ///   - token: 可选 Bearer Token
    /// - Returns: 响应字符串
    @discardableResult
    func httpPost(body: [String:Any],
                  headers: [String:String]? = nil,
                  timeout: TimeInterval? = nil,
                  token: String? = nil) async throws -> String {
        var client = HttpClient(url: self).withBody(body)
        if let headers { client = client.withHeaders(headers) }
        if let token { client = client.withToken(token) }
        if let timeout { client = client.withTimeout(timeout) }
        return try await client.post()
    }

    // MARK: - PUT
    /// 便捷 PUT 请求
    ///
    /// 用法示例：
    /// ```swift
    /// let url = URL(string: "https://httpbin.org/put")!
    /// let resp = try await url.httpPut(body: ["id": 1, "status": "ok"]) 
    /// ```
    @discardableResult
    func httpPut(body: [String:Any],
                 headers: [String:String]? = nil,
                 timeout: TimeInterval? = nil,
                 token: String? = nil) async throws -> String {
        var client = HttpClient(url: self).withBody(body)
        if let headers { client = client.withHeaders(headers) }
        if let token { client = client.withToken(token) }
        if let timeout { client = client.withTimeout(timeout) }
        return try await client.put()
    }

    // MARK: - PATCH
    /// 便捷 PATCH 请求
    ///
    /// 用法示例：
    /// ```swift
    /// let url = URL(string: "https://httpbin.org/patch")!
    /// let resp = try await url.httpPatch(body: ["op": "replace", "path": "/name", "value": "New"]) 
    /// ```
    @discardableResult
    func httpPatch(body: [String:Any],
                   headers: [String:String]? = nil,
                   timeout: TimeInterval? = nil,
                   token: String? = nil) async throws -> String {
        var client = HttpClient(url: self).withBody(body)
        if let headers { client = client.withHeaders(headers) }
        if let token { client = client.withToken(token) }
        if let timeout { client = client.withTimeout(timeout) }
        return try await client.patch()
    }

    // MARK: - DELETE
    /// 便捷 DELETE 请求
    ///
    /// 用法示例：
    /// ```swift
    /// let url = URL(string: "https://httpbin.org/delete")!
    /// try await url.httpDelete(token: "your_token")
    /// ```
    func httpDelete(headers: [String:String]? = nil,
                    timeout: TimeInterval? = nil,
                    token: String? = nil) async throws {
        var client = HttpClient(url: self)
        if let headers { client = client.withHeaders(headers) }
        if let token { client = client.withToken(token) }
        if let timeout { client = client.withTimeout(timeout) }
        try await client.delete()
    }
}


