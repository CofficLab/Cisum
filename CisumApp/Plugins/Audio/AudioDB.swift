import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

/// 音频记录数据库，负责管理音频模型的持久化存储和检索
/// 实现了 ModelActor 协议以支持 SwiftData 操作
/// 实现了 ObservableObject 协议以支持 SwiftUI 绑定
/// 实现了 SuperLog, SuperEvent, SuperThread 协议以支持日志记录、事件发送和线程管理
actor AudioDB: ModelActor, ObservableObject, SuperLog, SuperEvent, SuperThread {
    /// 用于日志输出的表情符号
    static let emoji = "📦"
    static let verbose = false

    /// SwiftData 模型容器
    let modelContainer: ModelContainer
    /// 模型执行器，用于执行模型操作
    let modelExecutor: any ModelExecutor
    /// 模型上下文，用于管理持久化存储
    let context: ModelContext
    /// 用于数据库操作的串行队列
    let queue = DispatchQueue(label: "DB")

    /// 初始化音频记录数据库
    /// - Parameters:
    ///   - container: SwiftData 模型容器
    ///   - reason: 初始化原因，用于日志记录
    ///   - verbose: 是否输出详细日志
    init(_ container: ModelContainer, reason: String) {
        self.modelContainer = container
        self.context = ModelContext(container)
        self.context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(
            modelContext: self.context
        )

        if Self.verbose {
            os_log("\(Self.i) with reason: \(reason)")
        }
    }

    /// 检查模型上下文是否有未保存的更改
    /// - Returns: 如果有未保存的更改则返回 true，否则返回 false
    func hasChanges() -> Bool {
        context.hasChanges
    }

    /// 插入一个持久化模型并保存上下文
    /// - Parameter model: 要插入的持久化模型
    /// - Throws: 如果插入或保存失败则抛出错误
    func insertModel(_ model: any PersistentModel) throws {
        context.insert(model)
        try context.save()
    }

    /// 删除指定类型的所有模型
    /// - Parameter model: 要删除的模型类型
    /// - Throws: 如果删除操作失败则抛出错误
    func destroy<T>(for model: T.Type) throws where T: PersistentModel {
        try context.delete(model: T.self)
    }

    /// 获取指定类型的所有模型
    /// - Returns: 指定类型的所有模型数组
    /// - Throws: 如果获取操作失败则抛出错误
    func all<T: PersistentModel>() throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    /// 以分页方式查询模型
    /// - Parameter page: 页码
    /// - Returns: 指定页的模型数组
    /// - Throws: 如果查询操作失败则抛出错误
    /// - Note: 当前实现未考虑分页参数，返回所有模型
    func paginate<T: PersistentModel>(page: Int) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    /// 获取符合指定条件的模型数量
    /// - Parameter predicate: 查询条件
    /// - Returns: 符合条件的模型数量
    /// - Throws: 如果查询操作失败则抛出错误
    func getCount<T: PersistentModel>(for predicate: Predicate<T>) throws -> Int {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    /// 按照指定条件查询多个模型
    /// - Parameter predicate: 查询条件
    /// - Returns: 符合条件的模型数组
    /// - Throws: 如果查询操作失败则抛出错误
    func get<T: PersistentModel>(for predicate: Predicate<T>) throws -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetch(descriptor)
    }

    /// 获取指定类型模型的总数量
    /// - Parameter model: 模型类型
    /// - Returns: 模型总数量
    /// - Throws: 如果查询操作失败则抛出错误
    func count<T>(for model: T.Type) throws -> Int where T: PersistentModel {
        let descriptor = FetchDescriptor<T>(predicate: .true)
        return try context.fetchCount(descriptor)
    }

    /// 执行代码并输出执行耗时
    /// - Parameters:
    ///   - title: 操作标题，用于日志输出
    ///   - tolerance: 耗时容忍度，超过此值才会输出耗时日志
    ///   - verbose: 是否输出详细日志
    ///   - code: 要执行的代码闭包
    func printRunTime(_ title: String, tolerance: Double = 0.1, verbose: Bool = false, _ code: () -> Void) {
        if verbose {
            os_log("\(self.t)\(title)")
        }

        let startTime = DispatchTime.now()

        code()

        // 计算代码执行时间
        let nanoTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1000000000

        if verbose && timeInterval > tolerance {
            os_log("\(self.t)\(title) cost \(timeInterval) 秒 🐢🐢🐢")
        }
    }

    /// 计算任务结束时的耗时并返回格式化的日志字符串
    /// - Parameters:
    ///   - startTime: 任务开始时间
    ///   - title: 任务标题
    ///   - tolerance: 耗时容忍度，用于判断是否为耗时操作
    /// - Returns: 格式化的日志字符串，包含任务标题和耗时
    /// - Note: 使用 nonisolated 修饰符允许在非隔离上下文中调用
    nonisolated func jobEnd(_ startTime: DispatchTime, title: String, tolerance: Double = 1.0) -> String {
        // 计算代码执行时间
        let nanoTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1000000000

        if timeInterval > tolerance {
            return "\(title) \(timeInterval) 秒 🐢🐢🐢"
        }

        return "\(title) \(timeInterval) 秒 🐢🐢🐢"
    }

    /// 获取所有音频模型
    /// - Parameter reason: 获取原因，用于日志记录
    /// - Returns: 所有音频模型数组，按顺序排序；如果获取失败则返回空数组
    func allAudios(reason: String) -> [AudioModel] {
        if Self.verbose {
            os_log("\(self.t)🚛 GetAllAudios 🐛 \(reason)")
        }

        do {
            let audios: [AudioModel] = try context.fetch(AudioModel.descriptorOrderAsc)

            return audios
        } catch let error {
            os_log(.error, "\(error.localizedDescription)")
            return []
        }
    }

    /// 获取所有音频的 URL
    /// - Parameter reason: 获取原因，用于日志记录
    /// - Returns: 所有音频 URL 数组
    func allAudioURLs(reason: String) -> [URL] {
        self.allAudios(reason: reason).map { $0.url }
    }

    /// 分页获取音频的 URL
    /// - Parameters:
    ///   - offset: 偏移量
    ///   - limit: 限制数量
    ///   - reason: 获取原因，用于日志记录
    /// - Returns: 音频 URL 数组
    func paginateAudioURLs(offset: Int, limit: Int, reason: String) -> [URL] {
        if Self.verbose {
            os_log("\(self.t)🚛 PaginateAudioURLs offset: \(offset), limit: \(limit) 🐛 \(reason)")
        }

        do {
            var descriptor = FetchDescriptor<AudioModel>()
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = limit
            descriptor.sortBy.append(.init(\.order, order: .forward))

            let audios: [AudioModel] = try context.fetch(descriptor)
            return audios.map { $0.url }
        } catch let error {
            os_log(.error, "\(error.localizedDescription)")
            return []
        }
    }

    /// 获取随机音频模型
    /// - Parameters:
    ///   - count: 要获取的音频数量，默认为 100
    ///   - reason: 获取原因，用于日志记录
    /// - Returns: 随机音频模型数组；如果获取失败则返回空数组
    func randomAudios(count: Int = 100, reason: String) -> [AudioModel] {
        os_log("\(self.t)GetRandomAudios 🐛 \(reason)")

        do {
            let audios: [AudioModel] = try self.all()
            return Array(audios.shuffled().prefix(count))
        } catch let error {
            os_log(.error, "\(error.localizedDescription)")
            return []
        }
    }

    /// 获取指定 URL 的音频数量
    /// - Parameter url: 音频 URL
    /// - Returns: 匹配该 URL 的音频数量；如果查询失败则返回 0
    func countOfURL(_ url: URL) -> Int {
        let descriptor = FetchDescriptor<AudioModel>(predicate: #Predicate<AudioModel> {
            $0.url == url
        })

        do {
            return try context.fetchCount(descriptor)
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
            return 0
        }
    }

    /// 删除指定 ID 的音频模型
    /// - Parameter id: 音频模型 ID
    /// - Returns: 删除后的下一个音频模型，当前实现始终返回 nil
    func delete(_ id: AudioModel.ID) -> AudioModel? {
        nil
    }

    /// 删除指定 URL 的音频
    /// - Parameter
    ///   - url: 音频 URL
    ///   - verbose: 是否输出详细日志
    /// - Throws: 如果删除操作失败则抛出错误
    func deleteAudio(url: URL, verbose: Bool = false) throws {
        if verbose {
            os_log("\(self.t)🚛 DeleteAudio \(url) 🐛")
        }

        if let audio = findAudio(url) {
            try deleteAudio(id: audio.id, verbose: verbose)
        }
    }

    /// 删除指定的音频模型
    /// - Parameters:
    ///   - audio: 要删除的音频模型
    ///   - verbose: 是否输出详细日志
    /// - Throws: 如果删除操作失败则抛出错误
    func deleteAudio(_ audio: AudioModel, verbose: Bool = false) throws {
        if verbose {
            os_log("\(self.t)🚛 DeleteAudio \(audio.url) 🐛")
        }

        try deleteAudio(id: audio.id, verbose: verbose)
    }

    /// 删除多个音频模型
    /// - Parameter
    ///   - audios: 要删除的音频模型数组
    ///   - verbose: 是否输出详细日志
    /// - Returns: 删除后的下一个音频模型
    /// - Throws: 如果删除操作失败则抛出错误
    func deleteAudios(_ audios: [AudioModel], verbose: Bool = false) throws -> AudioModel? {
        if verbose {
            os_log("\(self.t)🚛 DeleteAudios \(audios.count) 🐛")
        }

        return try deleteAudios(ids: audios.map { $0.id }, verbose: verbose)
    }

    /// 删除多个音频模型
    /// - Parameter ids: 要删除的音频模型 ID 数组
    /// - Returns: 删除后的下一个音频模型
    /// - Throws: 如果删除操作失败则抛出错误
    func deleteAudios(_ ids: [AudioModel.ID]) throws -> AudioModel? {
        try deleteAudios(ids: ids)
    }

    /// 删除多个 URL 对应的音频
    /// - Parameter
    ///   - urls: 要删除的音频 URL 数组
    ///   - verbose: 是否输出详细日志
    /// - Throws: 如果删除操作失败则抛出错误
    func deleteAudios(_ urls: [URL], verbose: Bool = false) throws {
        if verbose {
            os_log("\(self.t)🚛 DeleteAudios \(urls.count)")
        }

        for url in urls {
            try deleteAudio(url: url, verbose: verbose)
        }
    }

    /// 删除所有音频模型
    /// - Note: 如果删除操作失败，会记录错误但不会抛出异常
    func destroyAudios() {
        do {
            try destroy(for: AudioModel.self)
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    /// 取消喜欢指定的音频模型
    /// - Parameter audio: 要取消喜欢的音频模型
    /// - Note: 操作成功后会发送 AudioUpdatedNotification 通知
    func dislike(_ audio: AudioModel) {
        // 喜欢状态现在由 AudioLikePlugin 管理
        // 此方法保留以保持兼容性，但不再修改 AudioModel
        if Self.verbose {
            os_log("\(self.t)⚠️ dislike(_:) 方法已废弃，请使用 AudioLikePlugin")
        }
    }

    /// 取消喜欢指定 URL 的音频
    /// - Parameter url: 音频 URL
    /// - Note: 喜欢状态现在由 AudioLikePlugin 管理，此方法已废弃
    func dislike(_ url: URL) {
        // 喜欢状态现在由 AudioLikePlugin 管理
        // 此方法保留以保持兼容性，但不再修改 AudioModel
        if Self.verbose {
            os_log("\(self.t)⚠️ dislike(_:) 方法已废弃，请使用 AudioLikePlugin")
        }
    }

    /// 下载指定音频模型之后的下一个音频
    /// - Parameters:
    ///   - audio: 起始音频模型
    ///   - reason: 下载原因，用于日志记录
    /// - Throws: 如果下载操作失败则抛出错误
    func downloadNext(_ audio: AudioModel, reason: String) async throws {
        try await downloadNextBatch(audio, count: 2, reason: reason)
    }

    /// 批量下载指定音频模型之后的多个音频
    /// - Parameters:
    ///   - audio: 起始音频模型
    ///   - count: 要下载的音频数量，默认为 6
    ///   - reason: 下载原因，用于日志记录
    /// - Throws: 如果下载操作失败则抛出错误
    func downloadNextBatch(_ audio: AudioModel, count: Int = 6, reason: String) async throws {
        if Self.verbose {
            os_log("\(self.t)Download Next Batch(\(reason))")
        }

        var currentIndex = 0
        var currentAudio: AudioModel = audio

        while currentIndex < count {
            try await currentAudio.url.download(verbose: false, reason: "downloadNextBatch")

            currentIndex = currentIndex + 1
            if let next = self.nextOf(currentAudio) {
                currentAudio = next
            }
        }
    }

    /// 批量下载指定 URL 之后的多个音频
    /// - Parameters:
    ///   - url: 起始音频 URL
    ///   - count: 要下载的音频数量，默认为 6
    ///   - reason: 下载原因，用于日志记录
    /// - Throws: 如果下载操作失败则抛出错误
    func downloadNextBatch(_ url: URL, count: Int = 6, reason: String) async throws {
        if let audio = findAudio(url) {
            try await downloadNextBatch(audio, count: count, reason: reason)
        }
    }

    /// 发送排序完成事件
    /// - Parameter verbose: 是否输出详细日志
    func emitSortDone(verbose: Bool = false) {
        if verbose {
            os_log("\(self.t)🚀🚀🚀 EmitSortDone")
        }

        self.main.async {
            self.emit(name: .DBSortDone, object: nil)
        }
    }

    /// 发送正在排序事件
    /// - Parameters:
    ///   - mode: 排序模式
    ///   - verbose: 是否输出详细日志
    func emitSorting(_ mode: String, verbose: Bool = false) {
        if verbose {
            os_log("\(self.t)🚀🚀🚀 EmitSorting")
        }

        self.main.async {
            self.emit(name: .DBSorting, object: nil, userInfo: ["mode": mode])
        }
    }

    /// 根据 ID 查找音频模型
    /// - Parameter id: 音频模型 ID
    /// - Returns: 找到的音频模型，如果未找到则返回 nil
    func findAudio(_ id: AudioModel.ID) -> AudioModel? {
        context.model(for: id) as? AudioModel
    }

    /// 根据 URL 查找音频模型
    /// - Parameter url: 音频 URL
    /// - Returns: 找到的音频模型，如果未找到则返回 nil
    func findAudio(_ url: URL) -> AudioModel? {
        Self.findAudio(url, context: context)
    }

    /// 获取第一个音频模型
    /// - Returns: 第一个音频模型，如果没有音频则返回 nil
    /// - Throws: 如果查询操作失败则抛出错误
    func firstAudio() throws -> AudioModel? {
        try context.fetch(AudioModel.descriptorFirst).first
    }

    /// 获取第一个音频的 URL
    /// - Returns: 第一个音频的 URL，如果没有音频则返回 nil
    /// - Throws: 如果查询操作失败则抛出错误
    func firstAudioURL() throws -> URL? {
        try context.fetch(AudioModel.descriptorFirst).first?.url
    }

    /// 获取指定索引的音频模型
    /// - Parameter i: 音频索引
    /// - Returns: 指定索引的音频模型，如果未找到则返回 nil
    func get(_ i: Int) -> AudioModel? {
        Self.get(context: ModelContext(self.modelContainer), i)
    }

    /// 检查是否存在指定 URL 的音频
    /// - Parameter url: 音频 URL
    /// - Returns: 如果存在则返回 true，否则返回 false
    func hasAudio(_ url: URL) -> Bool {
        self.findAudio(url) != nil
    }

    /// 获取所有有标题的音频 URL
    /// - Returns: 所有有标题的音频 URL 数组，如果查询失败则返回空数组
    func getAllURLs() -> [URL] {
        let context = ModelContext(self.modelContainer)

        let predicate = #Predicate<AudioModel> {
            $0.title != ""
        }
        let descriptor = FetchDescriptor<AudioModel>(predicate: predicate)
        do {
            return try context.fetch(descriptor).map { $0.url }
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
            return []
        }
    }

    /// 获取所有音频的播放次数总和
    /// - Returns: 所有音频的播放次数总和
    func getAudioPlayTime() -> Int {
        var time = 0

        do {
            let audios = try context.fetch(AudioModel.descriptorAll)

            audios.forEach({
                time += $0.playCount
            })
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return time
    }

    /// 获取指定音频的子音频
    /// - Parameter audio: 父音频模型
    /// - Returns: 子音频模型数组，如果查询失败则返回空数组
    /// - Note: 子音频是指 URL 的父路径与给定音频 URL 相同的音频
    func getChildren(_ audio: AudioModel) -> [AudioModel] {
        do {
            let result = try context.fetch(AudioModel.descriptorAll).filter({
                $0.url.deletingLastPathComponent() == audio.url
            })

            return result
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return []
    }

    /// 获取指定 URL 的下一个音频模型
    /// - Parameters:
    ///   - url: 当前音频 URL
    ///   - verbose: 是否输出详细日志
    /// - Returns: 下一个音频模型，如果未找到则返回 nil
    /// - Throws: 如果查询操作失败则抛出错误
    func getNextOf(_ url: URL?, verbose: Bool = false) throws -> AudioModel? {
        if verbose {
            os_log("\(self.t)NextOf -> \(url?.lastPathComponent ?? "-")")
        }

        guard let url = url else {
            return nil
        }

        guard let audio = findAudio(url) else {
            return nil
        }

        Task {
            try? await self.downloadNext(audio, reason: "getNextOf")
        }
        return try nextOf(audio: audio)
    }

    /// 获取指定 URL 的下一个音频 URL
    /// - Parameters:
    ///   - url: 当前音频 URL
    ///   - verbose: 是否输出详细日志
    /// - Returns: 下一个音频 URL，如果未找到则返回 nil
    /// - Throws: 如果查询操作失败则抛出错误
    func getNextAudioURLOf(_ url: URL?, verbose: Bool = false) throws -> URL? {
        try self.getNextOf(url, verbose: verbose)?.url
    }

    /// 获取指定 URL 的上一个音频模型
    /// - Parameters:
    ///   - url: 当前音频 URL
    ///   - verbose: 是否输出详细日志
    /// - Returns: 上一个音频模型，如果未找到则返回 nil
    /// - Throws: 如果查询操作失败则抛出错误
    func getPrevOf(_ url: URL?, verbose: Bool = false) throws -> AudioModel? {
        if verbose {
            os_log("\(self.t)PrevOf -> \(url?.lastPathComponent ?? "-")")
        }

        guard let url = url else {
            return nil
        }

        guard let audio = self.findAudio(url) else {
            return nil
        }

        return try prev(audio)
    }

    /// 获取指定 URL 的上一个音频 URL
    /// - Parameters:
    ///   - url: 当前音频 URL
    ///   - verbose: 是否输出详细日志
    /// - Returns: 上一个音频 URL，如果未找到则返回 nil
    /// - Throws: 如果查询操作失败则抛出错误
    func getPrevAudioURLOf(_ url: URL?, verbose: Bool = false) throws -> URL? {
        try self.getPrevOf(url, verbose: verbose)?.url
    }

    /// 获取音频总数
    /// - Returns: 音频总数
    func getTotalOfAudio() -> Int {
        Self.getTotal(context: context)
    }

    /// 增加指定 URL 音频的播放次数
    /// - Parameter url: 音频 URL
    func increasePlayCount(_ url: URL) {
        if let a = findAudio(url) {
            a.playCount += 1
            do {
                try context.save()
            } catch let e {
                os_log(.error, "\(e.localizedDescription)")
                print(e)
            }
        }
    }

    /// 增加指定可选 URL 音频的播放次数
    /// - Parameter url: 可选音频 URL
    func increasePlayCount(_ url: URL?) {
        if let url = url {
            increasePlayCount(url)
        }
    }

    /// 插入音频模型
    /// - Parameters:
    ///   - audio: 要插入的音频模型
    ///   - force: 是否强制插入，即使已存在相同 URL 的音频
    /// - Note: 插入成功后会异步更新音频的哈希值
    func insertAudio(_ audio: AudioModel, force: Bool = false) {
        let url = audio.url

        if force == false && (findAudio(url) != nil) {
            return
        }

        context.insert(audio)

        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        Task {
            self.updateHash(audio)
        }
    }

    /// 检查是否所有音频都在云端
    /// - Returns: 如果有音频则返回 true，否则返回 false
    /// - Note: 当前实现仅检查是否有音频，而不是真正检查是否所有音频都在云端
    func isAllInCloud() -> Bool {
        getTotalOfAudio() > 0
    }

    /// 获取指定音频模型的下一个音频模型
    /// - Parameters:
    ///   - audio: 当前音频模型
    ///   - verbose: 是否输出详细日志
    /// - Returns: 下一个音频模型，如果未找到则返回 nil
    func nextOf(_ audio: AudioModel, verbose: Bool = false) -> AudioModel? {
        if verbose {
            os_log("\(self.t)NextOf -> \(audio.url.lastPathComponent)")
        }

        return nextOf(audio.url, verbose: verbose)
    }

    /// 获取指定 URL 的下一个音频模型
    /// - Parameters:
    ///   - url: 当前音频 URL
    ///   - verbose: 是否输出详细日志
    /// - Returns: 下一个音频模型，如果未找到则返回 nil
    func nextOf(_ url: URL?, verbose: Bool = false) -> AudioModel? {
        if verbose {
            os_log("\(self.t)NextOf -> \(url?.lastPathComponent ?? "-")")
        }

        guard let url = url else {
            return nil
        }

        guard let audio = self.findAudio(url) else {
            return nil
        }

        return audio
    }

    /// 获取指定音频模型的上一个音频模型
    /// - Parameter audio: 当前音频模型
    /// - Returns: 上一个音频模型，如果未找到或当前音频为 nil 则返回第一个音频
    /// - Throws: 如果查询操作失败则抛出错误
    func prev(_ audio: AudioModel?) throws -> AudioModel? {
        guard let audio = audio else {
            return try firstAudio()
        }

        let result = try context.fetch(AudioModel.descriptorPrev(order: audio.order))
        return result.first
    }

    /// 刷新音频模型，从数据库获取最新状态
    /// - Parameter audio: 要刷新的音频模型
    /// - Returns: 刷新后的音频模型，如果在数据库中未找到则返回原音频模型
    func refresh(_ audio: AudioModel) -> AudioModel {
        findAudio(audio.id) ?? audio
    }

    /// 按标题对音频进行排序，并可选择将特定音频置顶
    /// - Parameters:
    ///   - sticky: 要置顶的音频模型，如果为 nil 则不置顶任何音频
    ///   - reason: 排序原因，用于日志记录
    /// - Note: 排序会将置顶音频的顺序设为 0，其他音频从 100 开始递增
    func sort(_ sticky: AudioModel?, reason: String) {
        if AudioDB.verbose {
            os_log("\(self.t)Sort with reason: \(reason)")
        }

        emitSorting("order")

        // 前100留给特殊用途
        var offset = 100

        do {
            try context.enumerate(FetchDescriptor<AudioModel>(sortBy: [
                .init(\.title, order: .forward),
            ]), block: {
                if $0 == sticky {
                    $0.order = 0
                } else {
                    $0.order = offset
                    offset = offset + 1
                }
            })

            try context.save()
            emitSortDone()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
            emitSortDone()
        }
    }

    /// 按标题对音频进行排序，并可选择将特定 URL 的音频置顶
    /// - Parameters:
    ///   - url: 要置顶的音频 URL，如果为 nil 则不置顶任何音频
    ///   - reason: 排序原因，用于日志记录
    func sort(_ url: URL?, reason: String) {
        if let url = url {
            sort(findAudio(url), reason: reason)
        } else {
            sort(nil as AudioModel?, reason: reason)
        }
    }

    /// 随机排序音频，并可选择将特定音频置顶
    /// - Parameters:
    ///   - sticky: 要置顶的音频模型，如果为 nil 则不置顶任何音频
    ///   - reason: 排序原因，用于日志记录
    ///   - verbose: 是否输出详细日志
    /// - Throws: 如果排序操作失败则抛出错误
    func sortRandom(_ sticky: AudioModel?, reason: String, verbose: Bool) throws {
        if verbose {
            os_log("\(self.t)🐳🐳🐳 SortRandom with sticky: \(sticky?.title ?? "nil") 🐛 \(reason)")
        }

        emitSorting("random")

        try context.enumerate(FetchDescriptor<AudioModel>(), block: {
            if $0 == sticky {
                $0.order = 0
            } else {
                $0.randomOrder()
            }
        })

        try context.save()

        emitSortDone()
    }

    /// 随机排序音频，并可选择将特定 URL 的音频置顶
    /// - Parameters:
    ///   - url: 要置顶的音频 URL，如果为 nil 则不置顶任何音频
    ///   - reason: 排序原因，用于日志记录
    ///   - verbose: 是否输出详细日志
    /// - Throws: 如果排序操作失败则抛出错误
    func sortRandom(_ url: URL?, reason: String, verbose: Bool) throws {
        if let url = url {
            try sortRandom(findAudio(url), reason: reason, verbose: verbose)
        } else {
            try sortRandom(nil as AudioModel?, reason: reason, verbose: verbose)
        }
    }

    /// 将指定 URL 的音频置顶
    /// - Parameters:
    ///   - url: 要置顶的音频 URL
    ///   - reason: 置顶原因，用于日志记录
    /// - Note: 置顶会将指定音频的顺序设为 0，原置顶音频的顺序设为 1
    func sticky(_ url: URL?, reason: String) {
        guard let url = url else {
            return
        }

        os_log("\(self.t)Sticky \(url.lastPathComponent) with reason: \(reason)")

        do {
            // Find the audio corresponding to the URL
            guard let audioToSticky = findAudio(url) else {
                os_log(.error, "Audio not found for URL: \(url)")
                return
            }

            // Find the currently sticky audio (if any)
            let currentStickyAudio = try context.fetch(FetchDescriptor<AudioModel>(predicate: #Predicate { $0.order == 0 })).first

            // Update orders
            audioToSticky.order = 0
            currentStickyAudio?.order = 1

            try context.save()
        } catch let e {
            os_log(.error, "Error setting sticky audio: \(e.localizedDescription)")
        }
    }

    /// 初始化音频项目，同步数据库与提供的 URL 列表
    /// - Parameters:
    ///   - items: 音频 URL 列表
    ///   - verbose: 是否输出详细日志
    /// - Note: 此方法会更新已存在的音频，删除不在列表中的音频，并添加新的音频
    func initItems(_ items: [URL], verbose: Bool = false) {
        let startTime: DispatchTime = .now()

        // 将数组转换成哈希表，方便通过键来快速查找元素，这样可以将时间复杂度降低到：O(m+n)

        var hashMap = [URL: URL]()
        for element in items {
            hashMap[element] = element
        }

        do {
            try context.enumerate(FetchDescriptor<AudioModel>(), block: { audio in
                if let item = hashMap[audio.url] {
                    // 更新数据库记录
                    audio.size = item.getSize()

                    // 记录存在哈希表中，同步完成，删除哈希表记录
                    hashMap.removeValue(forKey: audio.url)
                } else {
                    context.delete(audio)
                }
            })

            // 余下的是需要插入数据库的
            for (_, value) in hashMap {
                context.insert(AudioModel(value))
            }

            try self.context.save()
        } catch {
            os_log(.error, "\(error.localizedDescription)")
        }

        if verbose {
            os_log("\(self.jobEnd(startTime, title: "\(self.t)✅ Sync(\(items.count))", tolerance: 0.01))")
        }

        NotificationCenter.postDBSynced()
    }

    /// 同步更新的音频项目
    /// - Parameters:
    ///   - metas: 更新的音频 URL 列表
    ///   - verbose: 是否输出详细日志
    /// - Note: 此方法会删除不存在的音频，并添加新的音频，但不会更新已存在的音频
    func syncWithUpdatedItems(_ metas: [URL], verbose: Bool = false) {
        let startTime: DispatchTime = .now()

        // 如果url属性为unique，数据库已存在相同url的记录，再执行context.insert，发现已存在的被替换成新的了
        // 但在这里，希望如果存在，就不要插入
        for (_, meta) in metas.enumerated() {
            if meta.isNotFileExist {
                let deletedURL = meta

                do {
                    try context.delete(model: AudioModel.self, where: #Predicate { audio in
                        audio.url == deletedURL
                    })
                } catch let e {
                    os_log(.error, "\(e.localizedDescription)")
                }
            } else {
                if findAudio(meta) == nil {
                    context.insert(AudioModel(meta))
                }
            }
        }

        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        if verbose {
            os_log("\(self.jobEnd(startTime, title: "\(self.t)✅ SyncWithUpdatedItems(\(metas.count))", tolerance: 0.01))")
        }

        NotificationCenter.postDBUpdated()
    }

    /// 更新音频模型
    /// - Parameters:
    ///   - audio: 要更新的音频模型
    ///   - verbose: 是否输出详细日志
    /// - Note: 如果音频标记为已删除，则会从数据库中删除；如果未找到音频，则不执行任何操作
    func update(_ audio: AudioModel, verbose: Bool = false) {
        if verbose {
            os_log("\(self.t)update \(audio.title)")
        }

        if var current = findAudio(audio.id) {
            if audio.isDeleted {
                context.delete(current)
            } else {
                current = audio
            }
        } else {
            if verbose {
                os_log("\(self.t)🍋 DB::update not found ⚠️")
            }
        }

        if context.hasChanges {
            try? context.save()
        } else {
            os_log("\(self.t)🍋 DB::update nothing changed 👌")
        }
    }

    /// 更新音频模型的封面状态
    /// - Parameters:
    ///   - audio: 音频模型
    ///   - hasCover: 是否有封面
    /// - Note: 如果保存失败，会记录错误但不会抛出异常
    func updateCover(_ audio: AudioModel, hasCover: Bool) {
        guard let dbAudio = context.model(for: audio.id) as? AudioModel else {
            return
        }

        dbAudio.hasCover = hasCover

        do {
            try context.save()
        } catch let e {
            os_log(.error, "保存Cover出错")
            os_log(.error, "\(e)")
        }
    }

    /// 更新音频模型的文件哈希值
    /// - Parameters:
    ///   - audio: 音频模型
    ///   - verbose: 是否输出详细日志
    /// - Note: 如果音频未下载或获取哈希值失败，则不执行更新
    func updateHash(_ audio: AudioModel, verbose: Bool = false) {
        if audio.url.isNotDownloaded {
            return
        }

        if verbose {
            os_log("\(self.t)UpdateHash for \(audio.title) 🌾🌾🌾 \(audio.getFileSizeReadable())")
        }

        let fileHash = audio.url.getHash()
        if fileHash.isEmpty {
            return
        }

        guard let dbAudio = context.model(for: audio.id) as? AudioModel else {
            return
        }

        dbAudio.fileHash = fileHash

        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    /// 删除指定 ID 的音频
    /// - Parameter id: 音频模型 ID
    /// - Returns: 删除后的下一个音频模型
    /// - Throws: 如果删除操作失败则抛出错误
    @discardableResult
    func deleteAudio(id: AudioModel.ID, verbose: Bool = false) throws -> AudioModel? {
        return try deleteAudios(ids: [id], verbose: verbose)
    }

    /// 删除多个 ID 的音频
    /// - Parameters:
    ///   - ids: 音频模型 ID 数组
    ///   - verbose: 是否输出详细日志
    /// - Returns: 删除后的下一个音频模型
    /// - Throws: 如果删除操作失败则抛出错误
    @discardableResult
    func deleteAudios(ids: [AudioModel.ID], verbose: Bool = true) throws -> AudioModel? {
        if verbose {
            os_log("\(self.t)🗑️ 数据库删除")
        }

        // 本批次的最后一个删除后的下一个
        var next: AudioModel?
        var deletedUrls: [URL] = []

        for (index, id) in ids.enumerated() {
            guard let audio = context.model(for: id) as? AudioModel else {
                os_log(.error, "\(self.t)删除时找不到")
                continue
            }

            let url = audio.url
            deletedUrls.append(url)

            // 找出本批次的最后一个删除后的下一个
            if index == ids.count - 1 {
                next = try nextOf(audio: audio)

                // 如果下一个等于当前，设为空
                if next?.url == url {
                    next = nil
                }
            }

            do {
                context.delete(audio)
                try context.save()
            } catch let e {
                os_log(.error, "\(self.t)删除出错 \(e)")
            }
        }

        // 发送删除完成通知，让 UI 知道需要刷新
        emitDeleted(urls: deletedUrls)

        return next
    }

    /// 发送删除完成事件
    /// - Parameters:
    ///   - urls: 被删除的音频 URL 列表
    ///   - verbose: 是否输出详细日志
    func emitDeleted(urls: [URL], verbose: Bool = false) {
        if verbose {
            os_log("\(self.t)🚀🚀🚀 EmitDeleted: \(urls.count) URLs")
        }

        self.main.async {
            self.emit(name: .dbDeleted, object: nil, userInfo: ["urls": urls])
        }
    }

    /// 通过 URL 删除音频，同时从磁盘和数据库中删除
    /// - Parameters:
    ///   - disk: 磁盘 URL
    ///   - urls: 要删除的音频 URL 数组
    /// - Returns: 删除后的下一个音频模型
    /// - Throws: 如果删除操作失败则抛出错误
    func deleteAudiosByURL(disk: URL, urls: [URL]) throws -> AudioModel? {
        // 本批次的最后一个删除后的下一个
        var next: AudioModel?

        for (index, url) in urls.enumerated() {
            do {
                guard let audio = try context.fetch(FetchDescriptor(predicate: #Predicate<AudioModel> {
                    $0.url == url
                })).first else {
                    os_log(.error, "\(self.t)删除时找不到")
                    continue
                }

                // 找出本批次的最后一个删除后的下一个
                if index == urls.count - 1 {
                    next = try nextOf(audio: audio)

                    // 如果下一个等于当前，设为空
                    if next?.url == url {
                        next = nil
                    }
                }

                // 从磁盘删除
                try audio.url.delete()

                // 从磁盘删除后，因为数据库监听了磁盘的变动，会自动删除
                // 但自动删除可能不及时，所以这里及时删除
                context.delete(audio)

                try context.save()
            } catch let e {
                os_log(.error, "\(self.t)删除出错 \(e)")
            }
        }

        return next
    }

    /// 根据 URL 查找音频模型（静态方法）
    /// - Parameters:
    ///   - url: 音频 URL
    ///   - context: 模型上下文
    ///   - verbose: 是否输出详细日志
    /// - Returns: 找到的音频模型，如果未找到则返回 nil
    static func findAudio(_ url: URL, context: ModelContext, verbose: Bool = false) -> AudioModel? {
        if verbose {
            os_log("\(self.t)FindAudio -> \(url.lastPathComponent)")
        }

        do {
            return try context.fetch(FetchDescriptor<AudioModel>(predicate: #Predicate<AudioModel> {
                $0.url == url
            })).first
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return nil
    }

    /// 获取指定索引的音频模型（静态方法）
    /// - Parameters:
    ///   - context: 模型上下文
    ///   - i: 音频索引
    /// - Returns: 指定索引的音频模型，如果未找到则返回 nil
    static func get(context: ModelContext, _ i: Int) -> AudioModel? {
        var descriptor = FetchDescriptor<AudioModel>()
        descriptor.fetchLimit = 1
        descriptor.fetchOffset = i
        // descriptor.sortBy.append(.init(\.downloadingPercent, order: .reverse))
        descriptor.sortBy.append(.init(\.order))

        do {
            let result = try context.fetch(descriptor)
            if let first = result.first {
                return first
            }
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return nil
    }

    /// 获取音频总数（静态方法）
    /// - Parameter context: 模型上下文
    /// - Returns: 音频总数，如果查询失败则返回 0
    static func getTotal(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor(predicate: #Predicate<AudioModel> {
            $0.order != -1
        })

        do {
            return try context.fetchCount(descriptor)
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
            return 0
        }
    }

    /// 获取指定音频模型的下一个音频模型
    /// - Parameter audio: 当前音频模型
    /// - Returns: 下一个音频模型，如果未找到则返回第一个音频
    /// - Throws: 如果查询操作失败则抛出错误
    func nextOf(audio: AudioModel) throws -> AudioModel? {
        let result = try context.fetch(AudioModel.descriptorNext(order: audio.order))
        if let first = result.first {
            return first
        }

        return try firstAudio()
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
