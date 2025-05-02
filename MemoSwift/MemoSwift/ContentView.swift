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
                folders: folders, 
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
    let folders: FetchedResults<Folder>
    @ObservedObject var folderViewModel: FolderViewModel
    
    @State private var showAddFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题区域
            HStack {
                Text("文件夹")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.leading)
                
                Spacer()
                
                Button(action: {
                    showAddFolder = true
                }) {
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
                ForEach(folders) { folder in
                    FolderRow(folder: folder)
                        .tag(folder)
                }
                .onDelete(perform: deleteFolder)
            }
            .listStyle(PlainListStyle())
        }
        .alert("新建文件夹", isPresented: $showAddFolder) {
            TextField("名称", text: $newFolderName)
            Button("取消", role: .cancel) {
                newFolderName = ""
            }
            Button("创建") {
                if !newFolderName.isEmpty {
                    folderViewModel.createFolder(name: newFolderName)
                    newFolderName = ""
                }
            }
        }
    }
    
    private func deleteFolder(at offsets: IndexSet) {
        for index in offsets {
            folderViewModel.deleteFolder(folder: folders[index])
        }
    }
    
    // 日期格式化器
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

// 文件夹行视图组件
private struct FolderRow: View {
    let folder: Folder
    
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
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 确保整行都可点击
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
                    }
                    .onDelete(perform: deleteNote)
                }
                .listStyle(PlainListStyle())
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func deleteNote(at offsets: IndexSet) {
        for index in offsets {
            noteViewModel.deleteNote(note: notes[index])
        }
    }
}

// 笔记行视图组件
private struct NoteRow: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.wrappedTitle.isEmpty ? "无标题" : note.wrappedTitle)
                .font(.headline)
                .lineLimit(1)
            
            HStack(alignment: .top, spacing: 8) {
                Text(note.wrappedContent.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.trailing, 4)
                
                Spacer()
                
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
                Button(action: onBack) {
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
                .onChange(of: title) { oldValue, newValue in
                    noteViewModel.updateNote(
                        note: note,
                        title: newValue,
                        content: content
                    )
                }
            
            Divider()
            
            // 内容输入区
            TextEditor(text: $content)
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color(.systemBackground))
                .onChange(of: content) { oldValue, newValue in
                    noteViewModel.updateNote(
                        note: note,
                        title: title,
                        content: newValue
                    )
                }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
