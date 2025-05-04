# MemoSwift

MemoSwift 是一款功能丰富的 iOS 备忘录应用，提供文件夹组织、iCloud 同步、OCR 文字识别和全文搜索功能，让您的笔记管理更加高效。

## 主要功能

- **三栏布局**: 文件夹列表、笔记列表和笔记编辑器
- **文件夹管理**: 创建、删除和组织笔记文件夹
- **实时同步**: 基于 iCloud 的多设备数据同步
- **OCR 文字识别**: 从图片中提取文字内容
- **全文搜索**: 快速检索所有笔记内容
- **自动保存**: 编辑内容实时保存
- **完整中文支持**: 全中文界面和错误提示

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

3. **搜索功能**
   - 使用搜索栏快速查找笔记内容
   - 支持全文检索和标题搜索

4. **OCR 文字识别**
   - 在笔记中添加图片
   - 使用 OCR 功能提取图片中的文字

## 项目结构

项目组织如下：

- **Models/**: 包含 Folder、Note 和 Image 数据模型
- **ViewModels/**: 包含 FolderViewModel、NoteViewModel 和 SearchViewModel
- **Views/**: SwiftUI 界面组件，按功能分类
  - Folder/: 文件夹相关视图
  - Note/: 笔记相关视图
  - OCR/: OCR 功能相关视图
  - Utils/: 通用工具视图
- **Services/**: 包含 OCRService 等服务类
- **Persistence.swift**: Core Data 堆栈和 iCloud 同步管理
- **MemoSwiftApp.swift**: 应用程序入口点
- **ContentView.swift**: 带有 NavigationSplitView 的主视图

## 技术特点

- **SwiftUI**: 使用最新的 SwiftUI 框架构建现代化 UI
- **Core Data**: 强大的数据持久化解决方案
- **iCloud 同步**: 数据在多设备间无缝同步
- **Vision 框架**: 用于 OCR 文字识别
- **错误处理**: 强大的错误捕获和恢复机制

## 开发路线图

详细的开发计划请查看 [roadmap.md](roadmap.md) 文件，其中包含：
- 已完成功能的清单
- 正在开发的功能
- 未来计划增加的功能
- 每日开发进展记录
