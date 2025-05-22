//
//  ContentView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import SwiftUI
import CoreData
import UIKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var folderViewModel: FolderViewModel
    @StateObject private var noteViewModel: NoteViewModel
    @StateObject private var searchViewModel = SearchViewModel(viewContext: PersistenceController.shared.container.viewContext)
    @StateObject private var trashViewModel: TrashViewModel
    @EnvironmentObject private var reminderViewModel: ReminderViewModel
    
    @FetchRequest(
        fetchRequest: Folder.allFoldersFetchRequest(),
        animation: .default
    ) private var folders: FetchedResults<Folder>
    
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var showSearchSheet = false
    @State private var showTrashView = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    init() {
        let viewContext = PersistenceController.shared.container.viewContext
        let folderVM = FolderViewModel(viewContext: viewContext)
        let noteVM = NoteViewModel(viewContext: viewContext, folderViewModel: folderVM)
        let trashVM = TrashViewModel(viewContext: viewContext, folderViewModel: folderVM, noteViewModel: noteVM)
        
        _folderViewModel = StateObject(wrappedValue: folderVM)
        _noteViewModel = StateObject(wrappedValue: noteVM)
        _trashViewModel = StateObject(wrappedValue: trashVM)
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
                        
                        // 添加搜索通知监听
                        setupSearchNotificationObserver()
                        
                        // 添加打开笔记的通知监听
                        setupOpenNoteNotificationObserver()
                        
                        // 添加处理提醒触发的通知监听
                        setupReminderTriggeredObserver()
                    }
            }
        }
        // 添加搜索表单
        .sheet(isPresented: $showSearchSheet) {
            SearchView(
                searchViewModel: searchViewModel,
                noteViewModel: noteViewModel,
                folderViewModel: folderViewModel
            )
        }
        // 添加回收站视图
        .sheet(isPresented: $showTrashView) {
            TrashView(trashViewModel: trashViewModel)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // 设置搜索通知监听器
    private func setupSearchNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ShowSearchSheet"),
            object: nil,
            queue: .main
        ) { _ in
            showSearchSheet = true
        }
    }
    
    // 设置打开笔记的通知监听器
    private func setupOpenNoteNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("OpenNoteFromNotification"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let noteId = userInfo["noteId"] as? UUID else {
                return
            }
            
            openNoteById(noteId)
        }
    }
    
    // 设置处理提醒触发的通知监听器
    private func setupReminderTriggeredObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("HandleReminderTriggered"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let reminderId = userInfo["reminderId"] as? UUID else {
                return
            }
            
            // 处理重复提醒
            reminderViewModel.handleReminderTriggered(reminderId: reminderId)
        }
    }
    
    // 根据ID打开笔记
    private func openNoteById(_ noteId: UUID) {
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND isInTrash == NO", noteId as CVarArg)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let note = results.first {
                // 设置笔记所属的文件夹为当前文件夹
                folderViewModel.selectedFolder = note.folder
                
                // 设置选中的笔记
                DispatchQueue.main.async {
                    noteViewModel.setSelectedNote(note)
                    
                    // 确保显示笔记详情
                    withAnimation(.navigationPush) {
                        columnVisibility = .detailOnly
                    }
                }
            }
        } catch {
            print("根据ID查找笔记失败: \(error)")
        }
    }
    
    var mainView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // First column: Folders and Tags
            VStack(spacing: 0) {
                // 文件夹列表
                FolderListView(folderViewModel: folderViewModel)
                    .environmentObject(noteViewModel)
                
                // 分隔线
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, 5)
                
                // 标签列表
                TagSelectionListView(noteViewModel: noteViewModel)
                
                // 分隔线
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, 5)
                
                // 回收站按钮
                Button(action: {
                    showTrashView = true
                }) {
                    HStack {
                        SwiftUI.Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .font(.headline)
                        
                        Text("回收站")
                            .font(.headline)
                        
                        Spacer()
                        
                        // 显示回收站项目数量
                        let itemCount = trashViewModel.getTrashItemCount()
                        if itemCount > 0 {
                            Text("\(itemCount)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color.clear)
                
                Spacer() // 推动内容到顶部
            }
            .onChange(of: folderViewModel.selectedFolder) { _, selectedFolder in
                // 当选中文件夹时，确保修改列可见性，避免直接跳到笔记编辑界面
                if selectedFolder != nil {
                    withAnimation(.navigationPush) {
                        // 确保文件夹选中时，columns显示为前两列
                        columnVisibility = .doubleColumn
                    }
                }
            }
            .onChange(of: noteViewModel.selectedNote) { _, note in
                if note != nil {
                    // 当选中笔记时，确保显示详情视图
                    withAnimation(.navigationPush) {
                        // 确保刷新CoreData上下文中的选中笔记
                        if let selectedNote = note {
                            viewContext.refresh(selectedNote, mergeChanges: true)
                        }
                        
                        // 确保笔记编辑器显示
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
                            withAnimation(.navigationPop) {
                                folderViewModel.selectedFolder = nil
                                // 在iPhone上显示文件夹列表列
                                columnVisibility = .doubleColumn
                            }
                        }
                    )
                } else {
                    // 当没有选中文件夹时显示提示
                    VStack {
                        Spacer()
                        Text("请选择一个文件夹")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        } detail: {
            // Third column: Note editor
            Group {
                if let note = noteViewModel.selectedNote {
                    NoteEditorView(
                        note: note,
                        noteViewModel: noteViewModel,
                        onBack: {
                            // 返回笔记列表
                            withAnimation(.navigationPop) {
                                noteViewModel.selectedNote = nil
                                // 在iPhone上显示笔记列表
                                columnVisibility = .doubleColumn
                            }
                        }
                    )
                    .environmentObject(reminderViewModel)
                } else {
                    // 当没有选中笔记时显示提示
                    VStack {
                        Spacer()
                        Text("请选择一个笔记")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// ContentErrorView被移除，使用独立的ErrorView.swift文件中的ErrorView

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
