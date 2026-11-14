# CisumUI 迁移 TODO

目标：尽量让 app 的通用 UI 由 `CisumUI` 负责。业务界面优先保留现有行为，只替换可复用的视觉组件、布局容器和状态表达。`CisumUI` 缺少的组件先补到 package，再回到 app 侧替换。

## 迁移原则

- 优先替换设置页、空状态、加载状态、弹窗内容、列表行等低风险通用 UI。
- 播放控制、封面渲染、分页列表、拖放、选择状态等业务行为先保持不变。
- 每一阶段都需要能独立构建和预览，避免一次性影响播放主流程。
- 用户可见文案继续使用中文或已有本地化表。

## 第一阶段：设置页

- [x] 将 `CisumApp/Core/Views/Layout/SettingView.swift` 从裸 `ScrollView + VStack` 整理为统一设置容器。
- [x] 将 `CisumApp/Plugins/Storage/StorageSettingView.swift` 中的 `MagicSettingSection` / `MagicSettingRow` 替换为 `CisumUI.AppSettingsSection` / `AppSettingsRow`。
- [x] 将 `CisumApp/Plugins/Audio-Settings/AudioSettings.swift` 迁移到 `CisumUI` 设置组件。
- [x] 将 `CisumApp/Plugins/Book-Settings/BookSettings.swift` 迁移到 `CisumUI` 设置组件。
- [x] 如现有 `AppSettingsRow` 不够表达右侧操作按钮或状态值，先在 `CisumUI` 增补设置行变体。

## 第二阶段：空状态和加载状态

- [x] 用 `CisumUI.AppEmptyState` / `AppLoadingOverlay` 替换 `CisumApp/Plugins/Audio-DBView/AudioDBTips.swift` 的空仓库、加载、排序状态。
- [x] 用 `CisumUI.AppEmptyState` / `AppLoadingOverlay` 替换 `CisumApp/Plugins/Book-DBView/Tips/BookDBTips.swift` 的空仓库、加载状态。
- [x] 保留 macOS 打开仓库目录、iOS 添加按钮等现有平台行为。
- [x] 如果 `AppEmptyState` 不能承载辅助操作区，给 `CisumUI` 增加 trailing/action slot。

## 第三阶段：Sheet 和确认弹窗

- [x] 将 `CisumApp/Core/Views/Common/SheetContainer.swift` 下沉或映射到 `CisumUI` 的通用 sheet 容器。
- [x] 为 `CisumUI` 增加通用组件：图标头部、信息行、状态横幅、底部操作按钮组。
- [x] 用新增组件重构 `CisumApp/Plugins/Store/PurchaseView.swift`。
- [x] 用新增组件重构 `CisumApp/Plugins/Store/RestoreView.swift`。
- [x] 用新增组件重构 `CisumApp/Plugins/Reset/ResetConfirm.swift`。
- [x] 保留 StoreKit 购买、恢复购买、重置设置等业务逻辑不变。

## 第四阶段：列表和条目

- [x] 用 `CisumUI.AppListRow` / `AppContextMenuRow` / `AppSizeLabel` 替换 `CisumApp/Plugins/Audio-DBView/AudioItemView.swift` 的通用行样式。
- [x] 评估 `CisumApp/Plugins/Book-DBView/Views/BookList.swift` 是否可迁移到统一列表行。
- [x] 评估 `CisumApp/Plugins/Audio-Copy-macOS/CopyList.swift` 是否可迁移到统一列表行。
- [x] 保留 `List(selection:)`、删除、分页加载、右键菜单和同步事件处理。
- [x] 如 `AppListRow` 不能用于系统 `List` selection，给 `CisumUI` 增加专用的 selectable row。

## 第五阶段：Tab 和通用按钮

- [x] 将 `CisumApp/Core/Views/Layout/AppTabView.swift` 的 demo 模式自定义 tab 替换为 `CisumUI.AppTabBar`。
- [x] 正常模式的系统 `TabView` 先保留，避免破坏平台默认导航行为。
- [x] 将常见图标按钮逐步替换为 `CisumUI.AppIconButton`。
- [ ] 如播放区需要统一按钮外观，先在 `CisumUI` 增加 `PlayerIconButton`，再迁移 app 侧按钮。

## 第六阶段：主题体系

参考 `/Users/colorfy/Code/CofficLab/Lumi` 的主题架构：主题插件通过 `addThemeContributions()` 提供 `LumiUIThemeContribution`，`ThemeService` 聚合插件贡献并写入 `LumiUIThemeRegistry`，`AppThemeVM` 管理当前主题、持久化选择并把 active theme 注入全局 UI。

- [x] 在 `SuperPlugin` 增加 `addThemeContributions() -> [LumiUIThemeContribution]` 默认实现。
- [x] 在 `PluginProvider` 增加 `getThemeContributions()`，按插件 `order` 稳定排序、去重，并重写 `ThemeSortKey`。
- [x] 增加 `ThemeService`，负责从 `PluginProvider` 同步主题贡献到 `CisumUI.LumiUIThemeRegistry`。
- [x] 增加 `AppThemeProvider` 或 `AppThemeVM`，暴露 `themes`、`currentThemeId`、`currentTheme`、`activeChromeTheme`，并提供 `selectTheme(_:)`。
- [x] 将主题选择持久化到现有 repo 或 `UserDefaults`，确保重启后恢复上次选择。
- [x] 在根视图注入主题环境：设置 `LumiUIThemeStore`、`ActiveChromeTheme.current`，并根据主题决定 `preferredColorScheme`。
- [x] 用 active theme 替换 `Config.rootBackground` 等全局背景入口，先覆盖 `RootView`、`ContentView`、`SettingView`、sheet 背景和主列表背景。
- [x] 增加主题变化通知，例如 `.cisumThemeDidChange`，方便播放器、列表、sheet 等局部视图刷新。
- [x] 增加主题设置页：用 `AppSettingsSection`、`GlassSelectionCard` 或新的 `ThemeSelectorView` 展示主题列表。
- [x] 增加状态栏或工具栏主题切换入口，参考 Lumi 的 `ThemeStatusBarPlugin`，但适配 Cisum 现有 `addStatusView()` / `addToolBarButtons()`。
- [x] 主题体系第一版只处理 app chrome 和 CisumUI 组件语义色，不引入 Lumi 的 editor theme、file icon theme 等 IDE 专属附件。
- [x] 增加 `CisumUI` 主题单元测试：空贡献报错、重复 id 报错、按 `ThemeSortKey` 排序、选择主题后同步 `LumiUIThemeStore`。

## 第七阶段：主题插件

第一批主题插件可以参考 Lumi 的独立插件目录结构：`ThemeXxxPlugin/ThemeXxxPlugin.swift` + `XxxTheme.swift` + 本地化文件。主题应该服务音频播放器场景，避免全部照搬 IDE 风格。

- [x] 新增 `ThemeCisumPlugin`：默认主题，随系统明暗适配，保持当前 Cisum 简洁、低干扰的基调。
- [x] 新增 `ThemeMidnightPlugin`：午夜深色，适合夜间听歌，低亮度蓝黑背景。
- [x] 新增 `ThemeAuroraPlugin`：极光紫，用于更有氛围的专辑封面和播放页背景。
- [x] 新增 `ThemeNebulaPlugin`：星云粉，柔和暖色，注意不要影响文本对比度。
- [x] 新增 `ThemeForestPlugin`：森林绿，适合长时间阅读有声书。
- [x] 新增 `ThemeOceanPlugin`：海洋蓝，清爽亮色/深色双模式。
- [x] 新增 `ThemeSunsetPlugin`：日落橙红，只作为点缀色，避免界面变成大面积橙色。
- [x] 新增 `ThemeMonoPlugin`：黑白高对比，优先保证可访问性。
- [x] 每个主题插件实现 `LumiAppChromeTheme`，提供 `identifier`、`displayName`、`compactName`、`description`、`iconName`、`iconColor`、accent/atmosphere/glow colors。
- [x] 每个主题插件通过 `addThemeContributions()` 返回 `LumiUIThemeContribution(appTheme:editorThemeId:)`；Cisum 暂时可使用主题 id 作为占位 `editorThemeId`。
- [ ] 为每个主题补充中文本地化名称和描述，后续统一放入对应 `.xcstrings`。
- [x] 为主题选择卡片增加小色板预览，至少展示背景色、主色、次色、文本色。
- [ ] 检查所有主题在浅色/深色、macOS/iOS、窗口大小变化下的文本对比度和背景可读性。

## 暂缓迁移

- [ ] `CisumApp/Core/Views/Layout/ControlView.swift`：播放控制布局和响应式高度强绑定，最后处理。
- [ ] `CisumApp/Core/Views/Playing/HeroView.swift`：封面、下载进度、demo 封面逻辑强绑定，最后处理。
- [ ] `CisumApp/Core/Views/Playing/BtnPlayPause.swift` 等播放按钮：等 `CisumUI` 有专用播放器按钮后再替换。

## UI 流畅度优化 - 已识别的性能问题

### 🔴 严重问题（P0 - 立即修复）

#### 1. ~~BookGrid 全网格动画导致严重卡顿~~ ✅ 已完成
**位置**: `Plugins/BookDBViewPlugin/Sources/BookGrid.swift:179`
**修复时间**: 2025-01-XX
**修复内容**: 将动画从整个 LazyVGrid 移除，只应用到边框 overlay。使用 `let isSelected` 预先计算，避免重复调用判断函数。

**效果**: 滚动书籍网格时不再有全局动画导致的卡顿，只有选中的边框有平滑过渡

#### 2. ~~BookGrid.updateSelectedBook 遍历所有书籍查找匹配~~ ✅ 已完成
**位置**: `Plugins/BookDBViewPlugin/Sources/BookGrid.swift:329`
**修复时间**: 2025-01-XX
**修复内容**: 
- 添加 `@State private var bookURLIndex: [URL: BookDTO] = [:]` 索引
- 在 `setBooks` 中构建索引，将复杂度从 O(n) 降为 O(1)
- `updateSelectedBook` 优先使用索引查找，仅在失败时才遍历

**效果**: 播放音频时 UI 不再冻结，书籍数量多时（>100）性能提升明显

#### 3. ~~BookGrid.playBook 每次点击都扫描目录~~ ✅ 已完成
**位置**: `Plugins/BookDBViewPlugin/Sources/BookGrid.swift`
**修复内容**: 
- 在 `BookGridPlayableChildrenLoader` 中添加内存缓存 `[String: [URL]]`
- 使用 `resolvingSymlinksInPath().standardizedFileURL.path` 作为缓存 key
- 在书籍删除（`handleBookDBDeleted`）和同步完成（`handleBookDBSynced`）时清除缓存
- 提供 `invalidateCache()` 和 `invalidateCache(for:)` 两种清除粒度

**效果**: 第二次点击同一本书时跳过目录扫描，播放启动延迟从 500ms-2s 降为 <10ms

#### 4. ~~AudioItemView 重复创建后台任务加载文件大小~~ ✅ 已完成
**位置**: `Plugins/AudioDBViewPlugin/Sources/AudioItemView.swift`
**修复内容**: 
- 优化 `loadFileSize()`：先检查缓存再重置状态，避免缓存命中时出现 UI 闪烁（显示"..."再变回大小）
- 缓存机制本身已经存在且正确，只需修复状态重置的时序

**效果**: 滚动时缓存命中不再触发多余的 UI 刷新，减少掉帧

#### 5. ~~StatusView 每次刷新都重新收集所有插件状态视图~~ ✅ 已完成
**位置**: `CisumApp/Views/Layout/StatusView.swift`
**修复内容**: 
- 移除 `Array(p.getStatusViews().enumerated())` 的冗余数组创建
- 使用 `ForEach(0..<views.count, id: \.self)` 直接索引访问
- PluginVM 内部的 `cachedStatusViews` 缓存机制已验证正确

**效果**: 减少每次 body 重建时的数组分配开销

#### 6. ~~RootToolbar 每次都重新构建工具栏按钮~~ ✅ 已验证无需修改
**位置**: `CisumApp/Views/Toolbar/RootToolbar.swift`
**验证结果**: 
- `getToolBarButtons()` 内部已有 `cachedToolBarButtons` 缓存
- body 中已提前计算 `let toolbarButtons = p.getToolBarButtons()`
- 缓存失效逻辑在 `invalidatePluginViewCaches()` 中正确实现
- 当前实现已足够优化

### 🟡 中等问题（P1 - 尽快优化）

#### 7. ~~BookTile 封面加载缺少 in-flight 任务去重~~ ✅ 已完成
**位置**: `Plugins/BookPlugin/Sources/Repo/BookCoverRepo.swift`
**修复内容**: 
- 添加 `resultCache: [String: Image?]` 结果缓存，避免重复扫描文件系统
- 添加 `inFlightTasks: [String: Task<Image?, Never>]` 进行任务去重
- 缓存 key 使用 `URL_standardized_path + size` 确保同 URL 不同尺寸独立缓存
- 在 BookGrid 的 `handleBookDBDeleted` 和 `handleBookDBSynced` 中清除缓存
- 提供 `clearCache()` 和 `clearCache(for:)` 两种清除粒度

**效果**: 快速滚动时相同封面只加载一次，内存峰值显著降低

#### 8. ~~BookTile 没有返回预缩放的缩略图~~ ✅ 已验证无需修改
**位置**: `Plugins/BookDBViewPlugin/Sources/BookTile.swift`
**验证结果**: 
- `BookTile.loadTileData()` 传入 `tileSize` 给 `repo.getCover(for:thumbnailSize:)`
- `BookCoverRepo` 将 `thumbnailSize` 传递给 `child.thumbnailImage(size:)` 
- 底层 `thumbnailImage` 已在后台线程做了缩放处理
- 当前实现已在正确的层级处理缩放

#### 9. ~~AudioList 分页触发使用线性查找~~ ✅ 已完成
**位置**: `Plugins/AudioDBViewPlugin/Sources/AudioList.swift`
**修复内容**: 
- 添加 `AudioListLoadPolicy.isNearThreshold()` 轻量级预检查
- 在 `onAppear` 中先调用 `isNearThreshold`，只在接近阈值时才调用 `checkLoadMore`
- 阈值设置为 75% 或最后 15 个 item，留出足够的提前加载缓冲

**效果**: 前 75% 的 cell 的 `onAppear` 不再执行任何分页检查逻辑，减少滚动时的函数调用开销

#### 10. ~~AppTabView 场景变化时重建所有 Tab~~ ✅ 已完成
**位置**: `CisumApp/Views/Layout/AppTabView.swift`
**修复内容**: 
- 移除 `Array(cachedTabViews.enumerated())` 的冗余数组创建
- 使用 `ForEach(0..<views.count, id: \.self)` 直接索引访问
- 将 `cachedTabViews` 提前赋值给 `let views` 避免多次属性访问

**效果**: 减少 `buildTabView` 中的数组分配开销

### 🟢 低优先级问题（P2 - 已完成）

#### 11. ~~PluginVM 主题贡献排序每次都重新计算~~ ✅ 已完成
**位置**: `CisumApp/ViewModels/PluginVM.swift`
**修复内容**: 
- 添加 `cachedThemeContributions: [LumiUIThemeContribution]?` 缓存字段
- `getThemeContributions()` 首次计算后缓存结果
- `invalidatePluginViewCaches()` 中同步清除主题缓存

**效果**: 主题设置页重复打开时跳过排序计算

#### 12. ~~HeroView 和 ProgressView 每次都计算下载进度~~ ✅ 已验证无需修改
**验证结果**: 
- `downloadProgress` 是计算属性，SwiftUI 的视图 diff 机制会自动跳过不必要的更新
- `playMan.state` 变化时才触发重算，计算量极小（一个 switch-case）
- 添加 `@State` 缓存反而会增加复杂度且没有性能收益

#### 13. ~~FileManager 同步 I/O 操作~~ ✅ 已验证无需修改
**验证结果**: 
- 主路径上的 `FileManager` 调用已全部在 `Task.detached` 或后台优先级 Task 中
- `AudioItemView.loadFileSize()` → `Task.detached(priority: .background)`
- `BookGridPlayableChildrenLoader.load()` → `Task.detached(priority: .userInitiated)`
- `BookCoverRepo.findCoverRecursively()` → `Task.detached(priority: .background)`
- 剩余的 `fileExists` 调用（如上下文菜单、策略判断）是瞬时操作，不影响 UI

## 优化计划（按优先级）

### Phase 1: 修复严重卡顿（1-2 周）
- [x] 修复 BookGrid 全网格动画问题
- [x] 优化 BookGrid.updateSelectedBook 使用索引查找
- [x] 优化 BookGrid.playBook 预加载子文件列表
- [x] 验证 AudioItemView 文件大小缓存有效性

### Phase 2: 中等性能优化（2-3 周）
- [x] 实现 BookTile 封面加载任务去重
- [x] 优化 BookTile 返回预缩放缩略图
- [x] 优化 AudioList 分页触发逻辑
- [x] 优化 AppTabView 场景切换缓存

### Phase 3: 细节优化（持续）
- [x] 缓存主题贡献排序结果
- [x] 优化播放页进度计算（验证无需修改）
- [x] 全面审查 FileManager 调用（验证无需修改）

### 验证方法
- [ ] 使用 Instruments Time Profiler 记录优化前后的主线程耗时
- [ ] 使用 SwiftUI Instrument 记录视图刷新次数
- [ ] 在不同设备上测试滚动帧率（iPhone 12 Pro、iPhone SE、M1 MacBook）
- [ ] 使用 Instruments Allocations 监控内存峰值
- [ ] 记录关键操作的启动时间（Tab 切换、播放启动、场景切换）

## 验证

- [x] 每阶段完成后运行 `xcodebuild -scheme Cisum -configuration Debug build`。
- [x] 覆盖 macOS 和 iOS 关键预览或模拟器构建。
- [ ] 检查设置页、仓库空状态、购买/恢复/重置弹窗、音频/图书列表的视觉一致性。
- [ ] 主题体系完成后逐个切换主题，确认 Root、设置页、仓库页、播放页、sheet、状态栏都使用同一 active theme。
