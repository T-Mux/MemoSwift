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
    
    @FetchRequest(
        fetchRequest: Folder.allFoldersFetchRequest(),
        animation: .default
    ) private var folders: FetchedResults<Folder>
    
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var showSearchSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    init() {
        let viewContext = PersistenceController.shared.container.viewContext
        let folderVM = FolderViewModel(viewContext: viewContext)
        let noteVM = NoteViewModel(viewContext: viewContext, folderViewModel: folderVM)
        
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
                        
                        // 添加搜索通知监听
                        setupSearchNotificationObserver()
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
    
    var mainView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // First column: Folders and Tags
            VStack(spacing: 0) {
                // 标题区域
                HStack {
                    Text("MemoSwift")
                        .font(.title)
                        .bold()
                    
                    Spacer()
                    
                    Button {
                        showSearchSheet = true
                    } label: {
                        SwiftUI.Image(systemName: "magnifyingglass")
                            .imageScale(.large)
                    }
                    .padding(.trailing, 8)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 完全恢复原始Layout
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
                                columnVisibility = .all
                            }
                        }
                    )
                    .environment(\.managedObjectContext, viewContext)
                } else {
                    EmptyNoteSelectionView()
                }
            }
            .animation(.navigationPush, value: folderViewModel.selectedFolder != nil)
        } detail: {
            // Third column: Note editor
            Group {
                if let selectedNote = noteViewModel.selectedNote {
                    // 简化视图结构，移除所有可能引起问题的修饰符
                    NoteEditorView(
                        note: selectedNote,
                        noteViewModel: noteViewModel,
                        onBack: {
                            // 返回笔记列表
                            withAnimation(.navigationPop) {
                                noteViewModel.selectedNote = nil
                                // 确保正确回到列表视图
                                if folderViewModel.selectedFolder != nil {
                                    columnVisibility = .doubleColumn
                                } else {
                                    columnVisibility = .automatic
                                }
                            }
                        }
                    )
                } else {
                    // 显示空视图
                    Color.clear
                }
            }
            .animation(.navigationPush, value: noteViewModel.selectedNote != nil)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct EmptyNoteSelectionView: View {
    var body: some View {
        VStack {
            SwiftUI.Image(systemName: "folder.badge.questionmark")
                .imageScale(.large)
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
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
