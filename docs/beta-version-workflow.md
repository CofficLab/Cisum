# Beta 版本迭代工作流程

## 版本命名规范

- **正式版本**: `v3.1.6` (主版本.次版本.修订版本)
- **Beta 版本**: `3.1.6-beta.N` (版本号-beta.迭代号)

## 工作流程说明

### 场景 1: 首次创建 Beta 版本

```text
dev 分支: feat: 添加新功能A
  ↓
merge dev → pre
  ↓
检测到 feat: 提交
  ↓
更新基础版本: 3.1.5 → 3.1.6
创建标签: 3.1.6-beta.1
创建 Release: 3.1.6-beta.1 (pre-release)
```

### 场景 2: Beta 版本迭代（修复 Bug）

```text
dev 分支: fix: 修复播放崩溃
  ↓
merge dev → pre
  ↓
只检测到 fix: 提交，无 feat:
  ↓
保持基础版本: 3.1.6
递增迭代号: beta.1 → beta.2
创建标签: 3.1.6-beta.2
创建 Release: 3.1.6-beta.2 (pre-release)
```

### 场景 3: Beta 版本迭代（继续修复）

```text
dev 分支:
  fix: 修复下载问题
  fix: 修复UI显示
  ↓
merge dev → pre
  ↓
只有 fix: 提交
  ↓
保持基础版本: 3.1.6
递增迭代号: beta.2 → beta.3
创建标签: 3.1.6-beta.3
```

### 场景 4: Beta 期间添加新功能

```text
dev 分支: feat: 添加播放列表
  ↓
merge dev → pre
  ↓
检测到 feat: 提交
  ↓
更新基础版本: 3.1.6 → 3.1.7
重置迭代号: beta.3 → beta.1
创建标签: 3.1.7-beta.1
```

### 场景 5: 正式发布（只发布最新版本）

```text
pre 分支经历多个 beta 版本:
  3.1.6-beta.1 → 3.1.6-beta.2 → 3.1.6-beta.3
  然后添加新功能: 3.1.7-beta.1
  ↓
merge pre → main
  ↓
获取最新的 beta 版本: 3.1.7-beta.1
  ↓
跳过中间未发布的版本 (3.1.6)
  ↓
创建标签: v3.1.7
创建 Release: v3.1.7 (正式版)
```

**重要说明：**
- Main 分支只发布**最新的 beta 版本**
- 中间的 beta 版本（如 3.1.6-beta.3）不会正式发布
- 这确保用户只获得经过充分测试的最新版本

## 版本示例

```text
开发阶段:
3.1.5 (v3.1.5 正式版)

首次 Beta:
3.1.6-beta.1 (添加新功能)

修复 Bug:
3.1.6-beta.2 (修复崩溃)
3.1.6-beta.3 (修复下载)

继续新功能:
3.1.7-beta.1 (添加播放列表)
3.1.7-beta.2 (修复UI)

正式发布 (只发布最新版本):
v3.1.7 ✅ (发布最新的 3.1.7-beta.2)
注意: 3.1.6 被跳过，因为它从未正式发布
```

## 自动化规则

### Pre 分支 (pre-bump.yaml)

**触发条件**: Push to pre branch

**版本判断逻辑**:

1. 检查自上次标签以来的提交
2. 如果有 `feat:` 或 `BREAKING CHANGE`:
   - 更新基础版本号 (3.1.6 → 3.1.7)
   - 重置迭代号为 .1
3. 如果只有 `fix:`, `chore:` 等:
   - 保持基础版本号不变
   - 递增迭代号 (beta.1 → beta.2)

**标签格式**: `3.1.6-beta.N`

### Main 分支 (pro-bump.yaml)

**触发条件**: Push to main branch

**版本判断逻辑**:

1. 获取最新的 beta 标签（如 `3.1.7-beta.2`）
2. 提取基础版本号（`3.1.7`）
3. 直接使用该版本号创建正式标签
4. **跳过中间未发布的 beta 版本**

**重要特性：**
- ✅ 只发布最新的 beta 版本
- ✅ 自动跳过未正式发布的版本
- ✅ 确保用户获得最新测试通过的版本

**标签格式**: `v3.1.7`

## 提交规范建议

### 功能开发

```bash
git commit -m "feat: 添加播放列表功能"
# → merge to pre 会更新基础版本
```

### Bug 修复

```bash
git commit -m "fix: 修复播放崩溃问题"
# → merge to pre 只递增迭代号
```

### 破坏性变更

```bash
git commit -m "feat!: 重构音频引擎API"
# → merge to main 会更新 major 版本
```

## 常见问题

**Q: 如果在 beta 期间发现需要大改怎么办？**
A: 正常提交 `feat:` 提交，系统会自动更新基础版本并重置迭代号。

**Q: 为什么 main 分支只发布最新版本？**
A: 这样可以：
- 避免发布未充分测试的中间版本
- 让用户直接获得最新最稳定的功能
- 简化版本管理，减少版本碎片

**Q: 如果想发布中间的 beta 版本（如 3.1.6）怎么办？**
A: 可以手动创建标签：
```bash
git checkout <commit-of-3.1.6-beta.3>
git tag v3.1.6
git push origin v3.1.6
# 然后手动创建 GitHub Release
```

**Q: 可以手动创建 beta 标签吗？**
A: 可以，但建议使用自动化流程。

**Q: 旧格式的 `p3.1.6` 标签怎么办？**
A: 会继续保留，不影响新格式的工作流程。

**Q: 如何回滚到上一个 beta 版本？**
A:

```bash
git checkout 3.1.6-beta.2
git checkout -b pre
git push origin pre --force
```
