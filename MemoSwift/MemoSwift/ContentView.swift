//
//  ContentView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var folderViewModel: FolderViewModel
    @StateObject private var noteViewModel: NoteViewModel
    
    @FetchRequest(
        fetchRequest: Folder.allFoldersFetchRequest(),
        animation: .default
    ) private var folders: FetchedResults<Folder>
    
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var hasError = false
    @State private var errorMessage = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    init() {
        let viewContext = PersistenceController.shared.container.viewContext
        let folderVM = FolderViewModel(viewContext: viewContext)
        let noteVM = NoteViewModel(viewContext: viewContext)
        
        _folderViewModel = StateObject(wrappedValue: folderVM)
        _noteViewModel = StateObject(wrappedValue: noteVM)
    }
    
    var body: some View {
        Group {
            if hasError {
                ErrorView(message: errorMessage)
            } else {
                mainView
                    .onAppear {
                        // 验证数据模型是否加载成功
                        do {
                            let _ = try viewContext.count(for: Folder.fetchRequest())
                        } catch {
                            hasError = true
                            errorMessage = "无法访问数据模型: \(error.localizedDescription)"
                        }
                    }
            }
        }
    }
    
    var mainView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // First column: Folders
            FolderListView(
                folderViewModel: folderViewModel
            )
        } content: {
            // Second column: Notes in selected folder
            if let selectedFolder = folderViewModel.selectedFolder {
                NoteListView(
                    folder: selectedFolder,
                    noteViewModel: noteViewModel,
                    onBack: {
                        // 返回文件夹列表
                        folderViewModel.selectedFolder = nil
                        // 在iPhone上显示文件夹列表列
                        columnVisibility = .all
                    }
                )
            } else {
                VStack {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .padding()
                    
                    Text("请选择一个文件夹")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        } detail: {
            // Third column: Note editor
            if let selectedNote = noteViewModel.selectedNote {
                NoteEditorView(
                    note: selectedNote,
                    noteViewModel: noteViewModel,
                    onBack: {
                        // 返回笔记列表
                        noteViewModel.selectedNote = nil
                    }
                )
            } else {
                VStack {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .padding()
                    
                    Text("请选择或创建一条笔记")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("加载错误")
                .font(.title)
                .bold()
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("尝试重新加载") {
                // 刷新应用
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else {
                    return
                }
                window.rootViewController = UIHostingController(rootView: ContentView())
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct FolderListView: View {
    @FetchRequest(
        fetchRequest: Folder.allFoldersFetchRequest(),
        animation: .default
    ) private var rootFolders: FetchedResults<Folder>
    
    @ObservedObject var folderViewModel: FolderViewModel
    
    @State private var showAddFolder = false
    @State private var newFolderName = ""
    @State private var createInCurrentFolder = false // 是否在当前选中的文件夹中创建
    @Environment(\.managedObjectContext) private var viewContext
    
    // 重命名相关状态
    @State private var showRenameDialog = false
    @State private var folderToRename: Folder? = nil
    @State private var renamedFolderName = ""
    
    // 移动相关状态
    @State private var showMoveDialog = false
    @State private var folderToMove: Folder? = nil
    @State private var targetFolders: [Folder] = []
    @State private var selectedTargetFolder: Folder? = nil
    
    // 删除确认状态
    @State private var showDeleteConfirmation = false
    @State private var folderToDelete: Folder? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题区域
            HStack {
                Text("文件夹")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.leading)
                
                Spacer()
                
                Menu {
                    Button(action: {
                        createInCurrentFolder = false
                        showAddFolder = true
                    }) {
                        Label("创建根文件夹", systemImage: "folder.badge.plus")
                    }
                    
                    if let selectedFolder = folderViewModel.selectedFolder {
                        Button(action: {
                            createInCurrentFolder = true
                            showAddFolder = true
                        }) {
                            Label("在 \"\(selectedFolder.name)\" 中创建", systemImage: "folder.fill.badge.plus")
                        }
                    }
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
            }
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            
            Divider()
            
            // 文件夹列表
            List(selection: $folderViewModel.selectedFolder) {
                ForEach(rootFolders) { folder in
                    FolderRowWithChildren(
                        folder: folder,
                        folderViewModel: folderViewModel,
                        onRename: {
                            folderToRename = folder
                            renamedFolderName = folder.name
                            showRenameDialog = true
                        },
                        onMove: {
                            folderToMove = folder
                            targetFolders = folderViewModel.getAvailableTargetFolders(forFolder: folder)
                            selectedTargetFolder = nil
                            showMoveDialog = true
                        },
                        onDelete: {
                            folderToDelete = folder
                            showDeleteConfirmation = true
                        }
                    )
                }
                .onDelete(perform: deleteFolder)
            }
            .listStyle(PlainListStyle())
            .onChange(of: folderViewModel.folderUpdated) { _, _ in
                // 刷新视图
                viewContext.refreshAllObjects()
            }
        }
        // 新建文件夹对话框
        .alert(createInCurrentFolder ? "新建子文件夹" : "新建文件夹", isPresented: $showAddFolder) {
            TextField("名称", text: $newFolderName)
            Button("取消", role: .cancel) {
                newFolderName = ""
            }
            Button("创建") {
                if !newFolderName.isEmpty {
                    if createInCurrentFolder, let parentFolder = folderViewModel.selectedFolder {
                        folderViewModel.createFolder(name: newFolderName, parentFolder: parentFolder)
                    } else {
                        folderViewModel.createFolder(name: newFolderName)
                    }
                    newFolderName = ""
                }
            }
        } message: {
            if createInCurrentFolder, let selectedFolder = folderViewModel.selectedFolder {
                Text("在文件夹 \"\(selectedFolder.name)\" 中创建新文件夹")
            }
        }
        // 重命名文件夹对话框
        .alert("重命名文件夹", isPresented: $showRenameDialog) {
            TextField("名称", text: $renamedFolderName)
            Button("取消", role: .cancel) { }
            Button("重命名") {
                if let folder = folderToRename, !renamedFolderName.isEmpty {
                    folderViewModel.renameFolder(folder: folder, newName: renamedFolderName)
                }
            }
        }
        // 移动文件夹对话框
        .sheet(isPresented: $showMoveDialog) {
            MoveTargetSelectionView(
                folderToMove: folderToMove,
                availableTargets: targetFolders,
                selectedTarget: $selectedTargetFolder,
                onCancel: { showMoveDialog = false },
                onConfirm: {
                    if let folder = folderToMove {
                        folderViewModel.moveFolder(folder: folder, toParent: selectedTargetFolder)
                        showMoveDialog = false
                    }
                }
            )
        }
        // 删除确认对话框
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let folder = folderToDelete {
                    folderViewModel.deleteFolder(folder: folder)
                }
            }
        } message: {
            if let folder = folderToDelete {
                Text("确定要删除文件夹 \"\(folder.name)\" 及其所有内容吗？此操作无法撤销。")
            }
        }
    }
    
    private func deleteFolder(at offsets: IndexSet) {
        for index in offsets {
            folderViewModel.deleteFolder(folder: rootFolders[index])
        }
    }
}

// 带子文件夹的文件夹行组件
private struct FolderRowWithChildren: View {
    @ObservedObject var folder: Folder
    let folderViewModel: FolderViewModel
    var onRename: () -> Void
    var onMove: () -> Void
    var onDelete: () -> Void
    
    @State private var isExpanded = false
    @State private var isShowingMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主文件夹行
            HStack(spacing: 5) {
                // 展开/折叠按钮（仅当有子文件夹时显示）
                Group {
                    if folder.childFoldersArray.count > 0 {
                        Button(action: {
                            withAnimation {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    } else {
                        // 为没有子文件夹的行添加灰色圆点
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(width: 15, alignment: .center)
                
                // 文件夹图标
                Image(systemName: "folder.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 25, alignment: .center)
                
                // 文件夹名称和信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.headline)
                    
                    HStack {
                        Text("\(folder.notesArray.count) 条笔记")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let createdDate = folder.createdAt {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatDate(createdDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer(minLength: 8)
                
                // 子文件夹指示器
                if folder.childFoldersArray.count > 0 {
                    Text("\(folder.childFoldersArray.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                        .padding(.trailing, 5)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 5)
            .background(folderViewModel.selectedFolder == folder ? Color(.systemGray6) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onTapGesture {
                folderViewModel.selectedFolder = folder
            }
            .contextMenu {
                // 上下文菜单
                Button(action: onRename) {
                    Label("重命名", systemImage: "pencil")
                }
                
                Button(action: onMove) {
                    Label("移动", systemImage: "folder.fill.badge.plus")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            }
            .onLongPressGesture {
                // 触发菜单显示
                isShowingMenu = true
            }
            
            // 子文件夹（仅在展开状态显示）
            if isExpanded && folder.childFoldersArray.count > 0 {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(folder.childFoldersArray) { childFolder in
                        FolderRowWithChildren(
                            folder: childFolder,
                            folderViewModel: folderViewModel,
                            onRename: {
                                onRename()
                            },
                            onMove: {
                                onMove()
                            },
                            onDelete: {
                                onDelete()
                            }
                        )
                        .padding(.leading, 22) // 精确的缩进以保持层次结构视觉一致
                    }
                }
                .padding(.top, 1)
                .padding(.bottom, 1)
            }
        }
        .padding(.vertical, 1)
        .actionSheet(isPresented: $isShowingMenu) {
            ActionSheet(
                title: Text("文件夹操作"),
                message: Text("选择对文件夹 \"\(folder.name)\" 的操作"),
                buttons: [
                    .default(Text("重命名")) {
                        onRename()
                    },
                    .default(Text("移动")) {
                        onMove()
                    },
                    .destructive(Text("删除")) {
                        onDelete()
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// 文件夹行视图组件 (保留用于其他部分的引用)
private struct FolderRow: View {
    let folder: Folder
    let folderViewModel: FolderViewModel
    var onRename: () -> Void
    var onMove: () -> Void
    var onDelete: () -> Void
    
    @State private var isShowingMenu = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.headline)
                
                HStack {
                    Text("\(folder.notesArray.count) 条笔记")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let createdDate = folder.createdAt {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(createdDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 子文件夹指示器
            if let childFolders = folder.childFolders, childFolders.count > 0 {
                Text("\(childFolders.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 确保整行都可点击
        .contextMenu {
            // 上下文菜单
            Button(action: onRename) {
                Label("重命名", systemImage: "pencil")
            }
            
            Button(action: onMove) {
                Label("移动", systemImage: "folder.fill.badge.plus")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .onLongPressGesture {
            // 触发菜单显示
            isShowingMenu = true
        }
        .actionSheet(isPresented: $isShowingMenu) {
            ActionSheet(
                title: Text("文件夹操作"),
                message: Text("选择对文件夹 \"\(folder.name)\" 的操作"),
                buttons: [
                    .default(Text("重命名")) {
                        onRename()
                    },
                    .default(Text("移动")) {
                        onMove()
                    },
                    .destructive(Text("删除")) {
                        onDelete()
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct NoteListView: View {
    let folder: Folder
    @ObservedObject var noteViewModel: NoteViewModel
    var onBack: () -> Void  // 新增返回回调
    
    @FetchRequest private var notes: FetchedResults<Note>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    
    init(folder: Folder, noteViewModel: NoteViewModel, onBack: @escaping () -> Void) {
        self.folder = folder
        self.noteViewModel = noteViewModel
        self.onBack = onBack
        
        let fetchRequest = Note.fetchRequestForFolder(folder: folder)
        _notes = FetchRequest(fetchRequest: fetchRequest, animation: .default)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏 - 重新设计的三部分布局
            HStack {
                // 左侧：返回按钮
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body)
                        Text("文件夹")
                            .font(.body)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.leading)
                .frame(width: 90, alignment: .leading)
                
                Spacer()
                
                // 中间：文件夹名称（居中显示，带图标）
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                        .font(.headline)
                        
                    Text(folder.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                // 右侧：添加笔记按钮
                Button(action: {
                    // 直接创建新笔记并选中
                    let newNote = noteViewModel.createNote(
                        title: "",
                        content: "",
                        folder: folder
                    )
                    noteViewModel.selectedNote = newNote
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
                .frame(width: 90, alignment: .trailing)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // 笔记列表
            if notes.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)
                    
                    Text("没有笔记")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("点击右上角按钮添加新笔记")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                List(selection: $noteViewModel.selectedNote) {
                    ForEach(notes) { note in
                        NoteRow(note: note)
                            .tag(note)
                            .id("\(note.id?.uuidString ?? "")-\(noteViewModel.noteUpdated)") // 使用noteUpdated触发刷新
                    }
                    .onDelete(perform: deleteNote)
                }
                .listStyle(PlainListStyle())
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // 当视图出现时，重新获取数据
            refreshData()
        }
        .onChange(of: noteViewModel.noteUpdated) { _, _ in
            // 当笔记数据更新时，刷新列表
            refreshData()
        }
    }
    
    // 刷新数据的函数
    private func refreshData() {
        // 刷新内存中的对象
        viewContext.refreshAllObjects()
        
        // 创建新的FetchRequest
        let fetchRequest = Note.fetchRequestForFolder(folder: folder)
        notes.nsPredicate = fetchRequest.predicate
        notes.nsSortDescriptors = fetchRequest.sortDescriptors ?? []
    }
    
    private func deleteNote(at offsets: IndexSet) {
        for index in offsets {
            noteViewModel.deleteNote(note: notes[index])
        }
    }
}

// 笔记行视图组件
private struct NoteRow: View {
    // 使用ObservedObject而不是let，以便自动刷新
    @ObservedObject var note: Note
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题显示
            Text(note.wrappedTitle.isEmpty ? "无标题" : note.wrappedTitle)
                .font(.headline)
                .lineLimit(1)
            
            HStack(alignment: .top, spacing: 8) {
                // 内容预览
                Text(note.wrappedContent.isEmpty ? "没有内容" : note.wrappedContent.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.trailing, 4)
                
                Spacer()
                
                // 更新日期
                Text(note.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 确保整行都可点击
    }
}

struct NoteEditorView: View {
    let note: Note
    @ObservedObject var noteViewModel: NoteViewModel
    var onBack: () -> Void  // 新增返回回调
    
    @State private var title: String
    @State private var content: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    @State private var debounceTimer: Timer?
    
    init(note: Note, noteViewModel: NoteViewModel, onBack: @escaping () -> Void) {
        self.note = note
        self.noteViewModel = noteViewModel
        self.onBack = onBack
        
        _title = State(initialValue: note.wrappedTitle)
        _content = State(initialValue: note.wrappedContent)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏 - 与文件夹界面保持一致的设计
            HStack {
                // 左侧：返回按钮
                Button(action: {
                    // 返回前确保立即保存当前更改
                    debounceTimer?.invalidate()
                    saveChanges()
                    
                    // 确保数据更新前强制刷新
                    viewContext.refreshAllObjects()
                    noteViewModel.forceRefresh()
                    
                    // 返回上一级
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body)
                        Text("返回")
                            .font(.body)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.leading)
                .frame(width: 90, alignment: .leading)
                
                // 中间：显示笔记标题或"新笔记"（居中显示，带图标）
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                        .font(.headline)
                    
                    Text(title.isEmpty ? "新笔记" : title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                // 右侧：预留空间保持对称
                Spacer()
                    .frame(width: 90)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // 标题输入框
            TextField("标题", text: $title)
                .font(.title3)
                .padding()
                .background(Color(.systemBackground))
                .onChange(of: title) { _, _ in
                    debounceSave()
                }
            
            Divider()
            
            // 内容输入区
            TextEditor(text: $content)
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color(.systemBackground))
                .onChange(of: content) { _, _ in
                    debounceSave()
                }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            // 视图消失时，停止所有计时器并立即保存
            debounceTimer?.invalidate()
            saveChanges()
            
            // 强制刷新确保所有更改可见
            noteViewModel.forceRefresh()
        }
    }
    
    // 延迟保存 - 使用计时器防抖
    private func debounceSave() {
        // 取消已有的计时器
        debounceTimer?.invalidate()
        
        // 创建新的计时器，延迟0.5秒后保存（缩短延迟时间提高响应性）
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            saveChanges()
        }
    }
    
    // 保存所有更改
    private func saveChanges() {
        // 仅当内容有变化时才更新
        if note.title != title || note.content != content {
            noteViewModel.updateNote(
                note: note,
                title: title,
                content: content
            )
            
            // 强制保存并刷新
            try? viewContext.save()
        }
    }
}

// 移动文件夹目标选择视图
struct MoveTargetSelectionView: View {
    let folderToMove: Folder?
    let availableTargets: [Folder]
    @Binding var selectedTarget: Folder?
    let onCancel: () -> Void
    let onConfirm: () -> Void
    
    @State private var searchText = ""
    
    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return availableTargets
        } else {
            return availableTargets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if availableTargets.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("没有可用的目标文件夹")
                            .font(.headline)
                        
                        Button("移动到根目录") {
                            selectedTarget = nil
                            onConfirm()
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        // 根目录选项
                        Button(action: {
                            selectedTarget = nil
                        }) {
                            HStack {
                                Image(systemName: "house")
                                    .foregroundColor(.blue)
                                Text("根目录")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedTarget == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        // 可用的目标文件夹
                        ForEach(filteredFolders) { folder in
                            Button(action: {
                                selectedTarget = folder
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.blue)
                                    Text(folder.name)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedTarget == folder {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "搜索文件夹")
                }
            }
            .navigationTitle("选择目标文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onConfirm()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
