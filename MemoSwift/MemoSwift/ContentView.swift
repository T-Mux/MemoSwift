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
                    // 当选中笔记时，确保显示详情视图
                    withAnimation(.navigationPush) {
                        columnVisibility = .detailOnly
                    }
                }
            }
        } content: {
            // Second column: Notes in selected folder
            ZStack {
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
                    .navigationTransition(isPresenting: true)
                    .zIndex(1) // 确保层级顺序正确
                } else {
                    EmptyNoteSelectionView()
                        .transition(.move(edge: .leading))
                }
            }
            .animation(.navigationPush, value: folderViewModel.selectedFolder != nil)
        } detail: {
            // Third column: Note editor
            ZStack {
                if let selectedNote = noteViewModel.selectedNote {
                    NoteEditorView(
                        note: selectedNote,
                        noteViewModel: noteViewModel,
                        onBack: {
                            // 返回笔记列表
                            withAnimation(.navigationPop) {
                                noteViewModel.selectedNote = nil
                                // 在iPhone上恢复到上一列
                                columnVisibility = .automatic
                            }
                        }
                    )
                    .navigationTransition(isPresenting: true)
                    .zIndex(1) // 确保层级顺序正确
                } else {
                    EmptyNoteEditorView()
                        .transition(.move(edge: .leading))
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
}

struct EmptyNoteEditorView: View {
    var body: some View {
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

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
