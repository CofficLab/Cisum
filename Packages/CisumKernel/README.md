# CisumKernel

Cisum 内核核心包（远程 LumiKernel 门面）。

- `CisumKernelContainer` 提供插件注册、服务注入与事件分发；Provider 注册表、
  归属记录与解析能力**委托给远程 [LumiKernel](https://github.com/CofficLab/LumiKernel.git)
  的 `KernelCoreContainer`**，与 Lumi / GitOK / Kuzee / Netto 共用同一内核实现。
- `SuperPlugin` 定义插件生命周期，`BuiltinPluginManager` 管理内置插件，
  `EventManager` 统一广播内核事件（应用特有层，保留在本包）。

原本地 `Packages/KernelCore` 已删除，改由本包 + 远程 LumiKernel 承担。
