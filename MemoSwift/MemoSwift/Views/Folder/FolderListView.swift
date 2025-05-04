//
//  FolderListView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI
import CoreData

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
    @State private var noteToMove: Note? = nil // 要移动的笔记
    @State private var showNoteMoveSheet = false // 控制笔记移动面板的显示
    
    // 创建一个文件夹操作状态对象
    @StateObject private var folderAction = FolderAction()
    
    // 显示笔记移动面板
    private func showMoveNoteSheet(note: Note) {
        noteToMove = note
        showNoteMoveSheet = true
    }
    
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
                                withAnimation(.navigationPop) {
                                    folderViewModel.selectedFolder = parentFolder
                                }
                            } else {
                                // 如果是根文件夹，才返回到根目录
                                withAnimation(.navigationPop) {
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
                        
                        Divider()
                        
                        Button(action: {
                            NotificationCenter.default.post(
                                name: Notification.Name("ShowSearchSheet"),
                                object: nil
                            )
                        }) {
                            Label("搜索笔记", systemImage: "magnifyingglass")
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
                            // 进入子文件夹
                            Button(action: {
                                withAnimation(.navigationPush) {
                                    folderViewModel.selectedFolder = folder
                                }
                            }) {
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
                                .contentTransition(.interpolate)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    folderAction.setupDelete(folder: folder)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    folderAction.setupRename(folder: folder)
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                                .tint(.orange)
                                
                                Button {
                                    folderAction.setupMove(
                                        folder: folder,
                                        availableTargets: folderViewModel.getAvailableTargetFolders(forFolder: folder)
                                    )
                                } label: {
                                    Label("移动", systemImage: "folder")
                                }
                                .tint(.blue)
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
                            Button(action: {
                                withAnimation(.navigationPush) {
                                    noteViewModel.selectedNote = note
                                }
                            }) {
                                NoteRow(note: note)
                                    .environmentObject(noteViewModel)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    noteViewModel.deleteNote(note: note)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                
                                Button {
                                    showMoveNoteSheet(note: note)
                                } label: {
                                    Label("移动", systemImage: "folder")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            } else {
                // 根目录下的文件夹列表
                ForEach(rootFolders) { folder in
                    // 进入文件夹
                    Button(action: {
                        withAnimation(.navigationPush) {
                            folderViewModel.selectedFolder = folder
                        }
                    }) {
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
                        .contentTransition(.interpolate)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            folderAction.setupDelete(folder: folder)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            folderAction.setupRename(folder: folder)
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        .tint(.orange)
                        
                        Button {
                            folderAction.setupMove(
                                folder: folder,
                                availableTargets: folderViewModel.getAvailableTargetFolders(forFolder: folder)
                            )
                        } label: {
                            Label("移动", systemImage: "folder")
                        }
                        .tint(.blue)
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
                        withAnimation(.navigationPush) {
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
                                        withAnimation(.navigationPush) {
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
            .environment(\.managedObjectContext, viewContext)
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
        // 笔记移动面板
        .sheet(isPresented: $showNoteMoveSheet) {
            if let note = noteToMove {
                NoteMoveTargetSelectionView(note: note)
                    .environmentObject(noteViewModel)
                    .environment(\.managedObjectContext, viewContext)
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