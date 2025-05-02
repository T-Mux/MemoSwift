# MemoSwift

MemoSwift 是一款功能丰富的 iOS 备忘录应用，具有文件夹组织、iCloud 同步、OCR 文字识别和快速搜索功能。

## 使用说明

1. **文件夹管理**
   - 点击"添加文件夹"按钮创建新文件夹
   - 左滑删除不需要的文件夹
   - 选择文件夹查看其中的笔记

2. **笔记操作**
   - 在选定文件夹中点击"添加笔记"创建新笔记
   - 左滑删除不需要的笔记
   - 点击笔记打开编辑界面
   - 修改内容自动保存

3. **iCloud 同步**
   - 应用自动将数据同步到 iCloud
   - 在多设备间保持数据一致

## 项目结构

项目组织如下：

- **Models/**: 包含 Folder 和 Note 的 Core Data 模型类
- **ViewModels/**: 包含业务逻辑的 ViewModel 类
- **Views/**: SwiftUI UI 组件视图
- **CoreDataModel/**: 包含 Core Data 模型定义
- **Persistence.swift**: Core Data 堆栈和 iCloud 同步管理
- **MemoSwiftApp.swift**: 应用程序入口点
- **ContentView.swift**: 带有 NavigationSplitView 的主视图

## 主要功能

- **三栏布局**: 文件夹列表、笔记列表和笔记编辑器
- **iCloud 同步**: 数据在多设备间无缝同步
- **中文本地化**: 完整的中文界面和错误提示
- **稳定性保障**: 强大的错误处理机制防止应用崩溃

## 开发路线图

详细的开发计划请查看 [roadmap.md](roadmap.md) 文件。
