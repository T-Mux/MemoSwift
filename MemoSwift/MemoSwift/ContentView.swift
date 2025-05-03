//
//  ContentView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import SwiftUI
import CoreData
import UIKit

// 添加环境值键，用于在组件间共享文件夹操作状态
private struct FolderActionKey: EnvironmentKey {
    static let defaultValue: FolderAction = FolderAction()
}

extension EnvironmentValues {
    var folderAction: FolderAction {
        get { self[FolderActionKey.self] }
        set { self[FolderActionKey.self] = newValue }
    }
}

// 文件夹操作状态类
class FolderAction: ObservableObject {
    @Published var folderToRename: Folder? = nil
    @Published var renamedFolderName: String = ""
    @Published var showRenameDialog: Bool = false
    
    @Published var folderToMove: Folder? = nil
    @Published var targetFolders: [Folder] = []
    @Published var selectedTargetFolder: Folder? = nil
    @Published var showMoveDialog: Bool = false
    
    @Published var folderToDelete: Folder? = nil
    @Published var showDeleteConfirmation: Bool = false
    
    func setupRename(folder: Folder) {
        self.folderToRename = folder
        self.renamedFolderName = folder.name
        self.showRenameDialog = true
    }
    
    func setupMove(folder: Folder, availableTargets: [Folder]) {
        self.folderToMove = folder
        self.targetFolders = availableTargets
        self.selectedTargetFolder = nil
        self.showMoveDialog = true
    }
    
    func setupDelete(folder: Folder) {
        self.folderToDelete = folder
        self.showDeleteConfirmation = true
    }
}

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
            .environmentObject(noteViewModel)
            .onChange(of: noteViewModel.selectedNote) { _, note in
                if note != nil {
                    // 当选中笔记时，确保显示详情视图（添加动画）
                    withAnimation(.easeInOut(duration: 0.3)) {
                        columnVisibility = .detailOnly
                    }
                }
            }
        } content: {
            // Second column: Notes in selected folder
            Group {
                if let selectedFolder = folderViewModel.selectedFolder {
                    NoteListView(
                        folder: selectedFolder,
                        noteViewModel: noteViewModel,
                        onBack: {
                            // 返回文件夹列表
                            withAnimation(.easeInOut(duration: 0.3)) {
                                folderViewModel.selectedFolder = nil
                                // 在iPhone上显示文件夹列表列
                                columnVisibility = .all
                            }
                        }
                    )
                    .transition(.opacity)
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
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: folderViewModel.selectedFolder != nil)
        } detail: {
            // Third column: Note editor
            Group {
                if let selectedNote = noteViewModel.selectedNote {
                    NoteEditorView(
                        note: selectedNote,
                        noteViewModel: noteViewModel,
                        onBack: {
                            // 返回笔记列表
                            withAnimation(.easeInOut(duration: 0.3)) {
                                noteViewModel.selectedNote = nil
                                // 在iPhone上恢复到上一列
                                columnVisibility = .automatic
                            }
                        }
                    )
                    .transition(.opacity)
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
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: noteViewModel.selectedNote != nil)
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
    @EnvironmentObject private var noteViewModel: NoteViewModel
    
    @State private var showAddFolder = false
    @State private var newFolderName = ""
    @State private var createInCurrentFolder = false // 是否在当前选中的文件夹中创建
    @State private var showPathNavigationMenu = false // 控制路径导航菜单的显示
    @Environment(\.managedObjectContext) private var viewContext
    
    // 创建一个文件夹操作状态对象
    @StateObject private var folderAction = FolderAction()
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题区域 - 使用ZStack确保标题居中
            ZStack {
                // 居中标题 - Files风格
                if let selectedFolder = folderViewModel.selectedFolder {
                    // 添加点击操作，显示路径菜单
                    Button(action: {
                        showPathNavigationMenu = true
                    }) {
                        HStack(spacing: 8) {
                            // 文件夹图标
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .font(.headline)
                            
                            // 文件夹名称和信息
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(selectedFolder.name)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                // 子标题显示"文件夹"字样
                                Text("文件夹 · \(selectedFolder.notesArray.count) 笔记")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Button(action: {
                        showPathNavigationMenu = true
                    }) {
                        HStack(spacing: 8) {
                            // 文件夹图标
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .font(.headline)
                            
                            // 文件夹名称和信息
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text("文件夹")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                // 子标题显示"根目录"字样
                                Text("根目录 · \(rootFolders.count) 文件夹")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                HStack {
                    // 根据是否有选中文件夹显示不同的左侧内容
                    if let selectedFolder = folderViewModel.selectedFolder {
                        // 显示返回按钮
                        Button(action: {
                            // 修改返回逻辑，返回到父文件夹而非根目录
                            if let parentFolder = selectedFolder.parentFolder {
                                // 如果有父文件夹，返回到父文件夹
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    folderViewModel.selectedFolder = parentFolder
                                }
                            } else {
                                // 如果是根文件夹，才返回到根目录
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    folderViewModel.selectedFolder = nil
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.body)
                                Text(selectedFolder.parentFolder != nil ? selectedFolder.parentFolder!.name : "文件夹")
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.leading)
                        .frame(width: 100, alignment: .leading)
                    } else {
                        // 根目录状态，预留空间
                        Spacer()
                            .frame(width: 100)
                    }
                    
                    Spacer()
                    
                    // 新设计：展开下拉菜单按钮
                    Menu {
                        Button(action: {
                            // 创建新文件夹
                            createInCurrentFolder = folderViewModel.selectedFolder != nil
                            showAddFolder = true
                        }) {
                            Label("新建文件夹", systemImage: "folder.badge.plus")
                        }
                        
                        if let selectedFolder = folderViewModel.selectedFolder {
                            Button(action: {
                                // 创建新笔记并选中
                                let newNote = noteViewModel.createNote(
                                    title: "",
                                    content: "",
                                    folder: selectedFolder
                                )
                                noteViewModel.selectedNote = newNote
                            }) {
                                Label("新建笔记", systemImage: "note.text.badge.plus")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                    .frame(width: 100, alignment: .trailing)
                }
            }
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        
        Divider()
        
        // 文件夹列表 - 修改为不展开的列表，点击直接进入
        List {
            // 如果有选中文件夹，则显示子文件夹和笔记
            if let selectedFolder = folderViewModel.selectedFolder {
                // 子文件夹区域
                Section(header: Text("子文件夹").font(.subheadline).foregroundColor(.secondary)) {
                    if selectedFolder.childFoldersArray.isEmpty {
                        Text("没有子文件夹")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(selectedFolder.childFoldersArray) { folder in
                            FolderRow(
                                folder: folder,
                                folderViewModel: folderViewModel,
                                onRename: {
                                    folderAction.setupRename(folder: folder)
                                },
                                onMove: {
                                    folderAction.setupMove(
                                        folder: folder,
                                        availableTargets: folderViewModel.getAvailableTargetFolders(forFolder: folder)
                                    )
                                },
                                onDelete: {
                                    folderAction.setupDelete(folder: folder)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    folderViewModel.selectedFolder = folder
                                }
                            }
                        }
                    }
                }
                
                // 笔记区域
                Section(header: Text("笔记").font(.subheadline).foregroundColor(.secondary)) {
                    if selectedFolder.notesArray.isEmpty {
                        Text("没有笔记")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(selectedFolder.notesArray) { note in
                            NoteRow(note: note)
                                .environmentObject(noteViewModel)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        noteViewModel.selectedNote = note
                                    }
                                }
                        }
                    }
                }
            } else {
                // 根目录下的文件夹列表
                ForEach(rootFolders) { folder in
                    FolderRow(
                        folder: folder,
                        folderViewModel: folderViewModel,
                        onRename: {
                            folderAction.setupRename(folder: folder)
                        },
                        onMove: {
                            folderAction.setupMove(
                                folder: folder,
                                availableTargets: folderViewModel.getAvailableTargetFolders(forFolder: folder)
                            )
                        },
                        onDelete: {
                            folderAction.setupDelete(folder: folder)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            folderViewModel.selectedFolder = folder
                        }
                    }
                }
                .onDelete(perform: deleteFolder)
            }
        }
        .listStyle(PlainListStyle())
        .onChange(of: folderViewModel.folderUpdated) { _, _ in
            // 刷新视图
            viewContext.refreshAllObjects()
        }
        .environment(\.folderAction, folderAction)
        // 路径导航菜单
        .sheet(isPresented: $showPathNavigationMenu) {
            NavigationView {
                List {
                    // 根目录选项
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            folderViewModel.selectedFolder = nil
                            showPathNavigationMenu = false
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "house.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 25, height: 25)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("根目录")
                                    .font(.headline)
                                
                                Text("\(rootFolders.count) 个文件夹")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if folderViewModel.selectedFolder == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if let selectedFolder = folderViewModel.selectedFolder {
                        let parentFolders = getParentFolders(for: selectedFolder)
                        
                        if !parentFolders.isEmpty {
                            Section(header: Text("上级文件夹").font(.caption).foregroundColor(.secondary)) {
                                // 父文件夹列表 (按照层级顺序显示)
                                ForEach(parentFolders.reversed(), id: \.id) { folder in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            folderViewModel.selectedFolder = folder
                                            showPathNavigationMenu = false
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "folder.fill")
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                                .frame(width: 25, height: 25)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(folder.name)
                                                    .font(.headline)
                                                
                                                Text("\(folder.childFoldersArray.count) 个子文件夹")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            if folder.id == folderViewModel.selectedFolder?.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // 当前文件夹
                        Section(header: Text("当前位置").font(.caption).foregroundColor(.secondary)) {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                    .frame(width: 25, height: 25)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedFolder.name)
                                        .font(.headline)
                                    
                                    Text("\(selectedFolder.notesArray.count) 笔记")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("选择位置")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showPathNavigationMenu = false
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // 新建文件夹对话框
        .alert(createInCurrentFolder ? "新建子文件夹" : "新建文件夹", isPresented: $showAddFolder) {
            TextField("名称", text: $newFolderName)
            Button("取消", role: .cancel) {
                newFolderName = ""
            }
            .tint(.blue)
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
            .disabled(newFolderName.isEmpty)
            .tint(newFolderName.isEmpty ? .gray : .blue)
        } message: {
            if createInCurrentFolder, let selectedFolder = folderViewModel.selectedFolder {
                Text("在文件夹 \"\(selectedFolder.name)\" 中创建新文件夹")
            }
        }
        // 重命名文件夹对话框
        .alert("重命名文件夹", isPresented: $folderAction.showRenameDialog) {
            TextField("名称", text: $folderAction.renamedFolderName)
            Button("取消", role: .cancel) { }
            .tint(.blue)
            Button("重命名") {
                if let folder = folderAction.folderToRename, !folderAction.renamedFolderName.isEmpty {
                    folderViewModel.renameFolder(folder: folder, newName: folderAction.renamedFolderName)
                }
            }
            .disabled(folderAction.renamedFolderName.isEmpty)
            .tint(folderAction.renamedFolderName.isEmpty ? .gray : .blue)
        }
        // 移动文件夹对话框
        .sheet(isPresented: $folderAction.showMoveDialog) {
            MoveTargetSelectionView(
                folderToMove: folderAction.folderToMove,
                availableTargets: folderAction.targetFolders,
                selectedTarget: $folderAction.selectedTargetFolder,
                onCancel: { folderAction.showMoveDialog = false },
                onConfirm: {
                    if let folder = folderAction.folderToMove {
                        folderViewModel.moveFolder(folder: folder, toParent: folderAction.selectedTargetFolder)
                        folderAction.showMoveDialog = false
                    }
                }
            )
        }
        // 删除确认对话框
        .alert("确认删除", isPresented: $folderAction.showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            .tint(.blue)
            Button("删除", role: .destructive) {
                if let folder = folderAction.folderToDelete {
                    folderViewModel.deleteFolder(folder: folder)
                }
            }
        } message: {
            if let folder = folderAction.folderToDelete {
                Text("确定要删除文件夹 \"\(folder.name)\" 及其所有内容吗？此操作无法撤销。")
            }
        }
    }
    
    private func deleteFolder(at offsets: IndexSet) {
        for index in offsets {
            folderViewModel.deleteFolder(folder: rootFolders[index])
        }
    }
    
    // 获取指定文件夹的所有父文件夹
    private func getParentFolders(for folder: Folder) -> [Folder] {
        var parentFolders: [Folder] = []
        
        var currentFolder: Folder? = folder.parentFolder
        while currentFolder != nil {
            parentFolders.append(currentFolder!)
            currentFolder = currentFolder!.parentFolder
        }
        
        return parentFolders
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
            // 顶部标题栏 - 新的布局结构，确保标题严格居中
            ZStack {
                // 居中标题
                Text(folder.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack {
                    // 左侧：返回按钮
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onBack()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.body)
                            Text("文件夹")
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.leading)
                    .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                    
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
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                    .frame(width: 100, alignment: .trailing)
                }
            }
            .padding(.vertical, 8)
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
                            .environmentObject(noteViewModel) // 传递noteViewModel给NoteRow
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
    @State private var isShowingMenu = false
    @State private var showMoveSheet = false
    @State private var showDeleteConfirmation = false
    
    // 引入NoteViewModel，以便可以删除和移动笔记
    @EnvironmentObject private var noteViewModel: NoteViewModel
    
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
        .onTapGesture {
            // 点击选择笔记，添加与文件夹相同的动画效果
            withAnimation(.easeInOut(duration: 0.3)) {
                noteViewModel.selectedNote = note
            }
        }
        .onLongPressGesture {
            // 长按显示操作菜单
            isShowingMenu = true
        }
        .contextMenu {
            // 上下文菜单支持（右键菜单）
            Button(action: {
                showMoveSheet = true
            }) {
                Label("移动", systemImage: "folder")
            }
            
            Button(action: {
                shareNote()
            }) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                Label("删除", systemImage: "trash")
            }
        }
        .actionSheet(isPresented: $isShowingMenu) {
            ActionSheet(
                title: Text("笔记操作"),
                message: Text("选择对笔记 \"\(note.wrappedTitle.isEmpty ? "无标题" : note.wrappedTitle)\" 的操作"),
                buttons: [
                    .default(Text("移动")) {
                        showMoveSheet = true
                    },
                    .default(Text("分享")) {
                        shareNote()
                    },
                    .destructive(Text("删除")) {
                        showDeleteConfirmation = true
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
        .sheet(isPresented: $showMoveSheet) {
            NoteMoveTargetSelectionView(note: note)
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            .tint(.blue)
            Button("删除", role: .destructive) {
                noteViewModel.deleteNote(note: note)
            }
        } message: {
            Text("确定要删除笔记 \"\(note.wrappedTitle.isEmpty ? "无标题" : note.wrappedTitle)\" 吗？此操作无法撤销。")
        }
    }
    
    // 分享笔记功能
    private func shareNote() {
        let noteContent = "标题：\(note.wrappedTitle)\n\n\(note.wrappedContent)"
        let activityVC = UIActivityViewController(activityItems: [noteContent], applicationActivities: nil)
        
        // 获取当前视图控制器来呈现分享界面
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// 笔记移动目标选择视图
struct NoteMoveTargetSelectionView: View {
    let note: Note
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var noteViewModel: NoteViewModel
    
    // 获取所有文件夹
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.name, ascending: true)],
        animation: .default
    ) private var allFolders: FetchedResults<Folder>
    
    @State private var selectedFolder: Folder?
    @State private var searchText = ""
    
    // 新增：跟踪展开状态的字典
    @State private var expandedFolders: [UUID: Bool] = [:]
    
    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return Array(allFolders)
        } else {
            return allFolders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // 根文件夹（没有父文件夹的）
    var rootFolders: [Folder] {
        filteredFolders.filter { $0.parentFolder == nil }
    }
    
    // 返回特定父文件夹下的所有子文件夹
    func childFolders(of parent: Folder) -> [Folder] {
        return filteredFolders.filter { $0.parentFolder == parent }
    }
    
    var body: some View {
        NavigationView {
            List {
                // 显示根文件夹及其子文件夹
                ForEach(rootFolders) { folder in
                    folderRow(folder: folder, level: 0)
                }
            }
            .searchable(text: $searchText, prompt: "搜索文件夹")
            .navigationTitle("移动笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("移动") {
                        if let targetFolder = selectedFolder {
                            noteViewModel.moveNote(note: note, toFolder: targetFolder)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(selectedFolder == nil)
                }
            }
        }
    }
    
    // 递归构建文件夹行，支持层级折叠
    @ViewBuilder
    func folderRow(folder: Folder, level: Int) -> some View {
        let hasChildren = childFolders(of: folder).count > 0
        let isExpanded = expandedFolders[folder.id ?? UUID()] ?? false
        
        Button(action: {
            if hasChildren {
                // 如果有子文件夹，则切换展开状态
                withAnimation {
                    if let id = folder.id {
                        expandedFolders[id] = !(expandedFolders[id] ?? false)
                    }
                }
            }
            // 不管是否有子文件夹，都可以选择当前文件夹
            selectedFolder = folder
        }) {
            HStack {
                // 缩进，根据层级增加缩进
                if level > 0 {
                    Spacer()
                        .frame(width: CGFloat(level) * 20)
                }
                
                // 文件夹图标，如果有子文件夹则显示折叠/展开图标
                if hasChildren {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Image(systemName: "folder")
                    .foregroundColor(.blue)
                
                Text(folder.name)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if selectedFolder == folder {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .contentShape(Rectangle())
        
        // 递归显示子文件夹
        if hasChildren && isExpanded {
            ForEach(childFolders(of: folder)) { childFolder in
                folderRow(folder: childFolder, level: level + 1)
            }
        }
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
            // 顶部导航栏 - 与文件夹界面保持一致的设计，确保标题居中
            ZStack {
                // 居中标题
                Text(title.isEmpty ? "新笔记" : title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack {
                    // 左侧：返回按钮
                    Button(action: {
                        // 返回前确保立即保存当前更改
                        debounceTimer?.invalidate()
                        saveChanges()
                        
                        // 确保数据更新前强制刷新
                        viewContext.refreshAllObjects()
                        noteViewModel.forceRefresh()
                        
                        // 返回上一级（添加动画效果）
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onBack()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.body)
                            Text("返回")
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.leading)
                    .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                    
                    // 右侧：预留空间保持对称
                    Spacer()
                        .frame(width: 100)
                }
            }
            .padding(.vertical, 8)
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
    
    // 新增：跟踪展开状态的字典
    @State private var expandedFolders: [UUID: Bool] = [:]
    
    // 筛选和分组文件夹
    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return availableTargets
        } else {
            return availableTargets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // 根文件夹（没有父文件夹的）
    var rootFolders: [Folder] {
        filteredFolders.filter { $0.parentFolder == nil }
    }
    
    // 返回特定父文件夹下的所有子文件夹
    func childFolders(of parent: Folder) -> [Folder] {
        return filteredFolders.filter { $0.parentFolder == parent }
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
                        
                        // 显示根文件夹及其子文件夹
                        ForEach(rootFolders) { folder in
                            folderRow(folder: folder, level: 0)
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
    
    // 递归构建文件夹行，支持层级折叠
    @ViewBuilder
    func folderRow(folder: Folder, level: Int) -> some View {
        let hasChildren = childFolders(of: folder).count > 0
        let isExpanded = expandedFolders[folder.id ?? UUID()] ?? false
        
        Button(action: {
            if hasChildren {
                // 如果有子文件夹，则切换展开状态
                withAnimation {
                    if let id = folder.id {
                        expandedFolders[id] = !(expandedFolders[id] ?? false)
                    }
                }
            } else {
                // 如果没有子文件夹，则选择此文件夹
                selectedTarget = folder
            }
        }) {
            HStack {
                // 缩进，根据层级增加缩进
                if level > 0 {
                    Spacer()
                        .frame(width: CGFloat(level) * 20)
                }
                
                // 文件夹图标，如果有子文件夹则显示折叠/展开图标
                if hasChildren {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Image(systemName: "folder")
                    .foregroundColor(.blue)
                
                Text(folder.name)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 选择图标
                Button(action: {
                    selectedTarget = folder
                }) {
                    if selectedTarget == folder {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        
        // 递归显示子文件夹
        if hasChildren && isExpanded {
            ForEach(childFolders(of: folder)) { childFolder in
                folderRow(folder: childFolder, level: level + 1)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
