# Cisum ProviderToast 设计

## 背景

Cisum 当前通过 MagicAlert 的全局单例直接渲染消息。这样业务代码无法依赖一个可替换的能力契约，主窗口和设置窗口也各自挂载渲染器。GitOK 的 `ProviderToast` / `PluginToast` 将消息能力、状态机和 UI 宿主拆开，Cisum 采用同样的边界。

## 设计

- `ProviderToast`：定义 `CisumToast`、`CisumErrorNotice`、`CisumLoadingNotice`、`CisumToastStyle` 和 `ToastProviding`。
- `DefaultToastProvider`：内核启动前注册的 no-op 实现，保证插件可以安全调用提示能力。
- `PluginToast`：实现 `ToastProvider`，将短消息、加载状态、持久错误集中到一个主线程状态机；错误保留完整文本并支持复制/关闭。
- `ProviderRootView`：增加有序 `RootOverlayItem`，由插件在启动阶段把 Toast 渲染器挂到根视图。
- `FactoryCisum`：在插件启动前注册视图 Provider，在默认插件清单中加入始终启用的 Toast 插件；设置窗口复用同一个 `ToastProvider`。
- `MagicKit`：保留旧 `alert_*` 函数作为兼容层，但实现改为转发到当前 `ToastProviding`，避免现有插件遗漏迁移。

## 生命周期

1. Factory 注册 `DefaultToastProvider` 和 `RootViewProviding`。
2. `ToastPlugin.onBoot` 用 `ToastProvider` 替换默认 Provider，并注册根覆盖层。
3. 业务代码调用 `ToastProviding`（或兼容层 `alert_*`）只改变状态，不关心 UI。
4. 主窗口根布局和设置窗口观察同一个 `ToastProvider`。
5. Kernel 销毁时 Toast 插件撤销覆盖层并清空状态。

## 行为约定

- info/success/warning/error 短消息默认 3 秒、4 秒、4 秒、3 秒后消失；新消息替换旧消息并重置计时器。
- loading 持续显示，直到显式 dismiss 或被下一条消息替换。
- 错误默认显示持久面板，不自动消失；完整文本可选中、复制并由用户关闭。
- Provider 方法全部运行在 `MainActor`，不抛异常；未安装渲染插件时 no-op。

## 取舍

兼容层保留 `alert_*` API，降低本次迁移对几十个现有调用点和测试的影响。新增代码应直接解析 `ToastProviding`；MagicAlert 依赖和根渲染器已在本次迁移中移除，后续可以按插件逐步删除兼容调用。
