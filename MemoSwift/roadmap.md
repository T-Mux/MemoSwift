# MemoSwift 开发路线图

## 项目概述
MemoSwift 是一款 iOS 备忘录应用，具有以下特点：
- 类似 AppNotes 的简洁直观界面
- 笔记文件夹分类管理
- iCloud 同步功能
- OCR（光学字符识别）技术
- 快速检索功能

## 开发时间线

### 第一阶段：基础搭建
- [x] 项目初始化
- [x] 基本 UI 架构设计
- [x] Core Data 数据模型设计
- [x] 文件系统管理实现
- [x] 基本笔记创建和编辑功能

### 第二阶段：核心功能
- [x] 文件夹组织实现
- [x] 笔记分类系统
- [x] 文本格式化选项
- [x] 基本搜索功能
- [x] 本地数据持久化

### 第三阶段：高级功能
- [x] iCloud 同步
- [x] OCR 文字识别实现
- [x] 高级搜索和筛选
- [ ] 媒体附件（照片、涂鸦）
- [ ] 导出/导入功能

### 第四阶段：完善和发布
- [x] UI/UX 优化
- [x] 性能优化
- [ ] 跨设备测试


## 每日进展

### [2025-05-02]
- 创建项目路线图
- 完成初步需求收集
- 搭建开发环境
- 设置三栏布局导航（NavigationSplitView）
- 创建带有文件夹和笔记实体的 Core Data 模型
- 实现 iCloud 和 App Group 功能
- 添加 iCloud 同步的后台处理
- 创建基本 UI（文件夹列表、笔记列表和笔记编辑器）
- 实现基本笔记创建、编辑和删除功能
- 添加文件夹管理（创建和删除操作）
- 修复构建问题：
  - 解决 Core Data 模型重复冲突
  - 将 PersistenceController 从结构体改为类以修复 @objc 属性错误
  - 更新 Core Data 模型引用路径
  - 为必填属性添加默认值
  - 更正 Core Data 模型目录结构
- 解决应用启动崩溃问题：
  - 修复了 Core Data 模型加载时的空值解包错误
  - 重构了 Persistence.swift 实现更安全的模型加载方式
  - 添加了友好的错误处理界面，防止应用崩溃
  - 修复了全局错误捕获机制中 DispatchQueue.main.sync 的歧义错误
  - 改进错误处理使用 NSSetUncaughtExceptionHandler 代替不安全的方法
  - 优化中文本地化界面
  - 添加了详细的故障排除说明
- 解决 Core Data 模型加载问题：
  - 实现了内存中动态创建数据模型的方案，无需外部 xcdatamodeld 文件
  - 手动定义了所有实体、属性和关系，确保模型完整性
  - 添加了详细的日志记录，便于调试
  - 改进了错误处理流程，不再使用 fatalError 导致应用崩溃
  - 优化了持久化存储配置

### [2025-05-03]

- 修复笔记实时预览的问题：
  - 改进NoteListView，使用noteViewModel.noteUpdated作为列表行的ID部分，确保数据变化时视图能更新；添加了.onChange(of: noteViewModel.noteUpdated)监听器刷新数据；优化refreshData()方法来刷新FetchRequest
  - 优化NoteRow组件，将note改为@ObservedObject以便自动刷新；改进了空内容的显示逻辑
  - 增强了NoteEditorView，在返回按钮操作中添加了noteViewModel.forceRefresh()调用；在onDisappear时添加了强制刷新机制；使用计时器防抖技术优化自动保存逻辑，从1秒减少到0.5秒提高响应速度
- 为文件夹和笔记添加多种操作逻辑
- 修改了UI视图，使笔记的操作逻辑更符合用户习惯
- 在切换文件夹时加入动画效果

### [2025-05-04]

- 新增快速检索与全文搜索功能
- 修复启动时闪退、切换笔记闪烁、无法移动笔记的bug
- 新增 OCR 功能（未实际测试）
- 新增笔记界面多种操作功能