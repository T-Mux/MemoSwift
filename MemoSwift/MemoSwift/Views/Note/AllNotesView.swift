//
//  AllNotesView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI
import CoreData

struct AllNotesView: View {
    @ObservedObject var noteViewModel: NoteViewModel
    @ObservedObject var folderViewModel: FolderViewModel
    var onBack: () -> Void  // 返回回调
    
    @FetchRequest private var notes: FetchedResults<Note>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showMoveSheet = false
    @State private var moveNote: Note?
    @State private var showOCRView = false // OCR视图状态
    @State private var selectedTag: Tag?
    @State private var showingTagFilter = false
    @State private var showingSortOptions = false
    @State private var sortOption: SortOption = .modifiedDate
    
    // 排序选项枚举
    enum SortOption: String, CaseIterable {
        case modifiedDate = "修改时间"
        case createdDate = "创建时间"
        case title = "标题"
        
        var systemImage: String {
            switch self {
            case .modifiedDate: return "clock"
            case .createdDate: return "calendar"
            case .title: return "textformat.abc"
            }
        }
    }
    
    // 计算排序后的笔记
    private var sortedNotes: [Note] {
        let notesArray = Array(notes)
        switch sortOption {
        case .modifiedDate:
            return notesArray.sorted { ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast) }
        case .createdDate:
            return notesArray.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .title:
            return notesArray.sorted { $0.wrappedTitle.localizedCaseInsensitiveCompare($1.wrappedTitle) == .orderedAscending }
        }
    }
    
    init(noteViewModel: NoteViewModel, folderViewModel: FolderViewModel, onBack: @escaping () -> Void, selectedTag: Tag? = nil) {
        print("AllNotesView: 初始化")
        self.noteViewModel = noteViewModel
        self.folderViewModel = folderViewModel
        self.onBack = onBack
        self.selectedTag = selectedTag

        let fetchRequest: NSFetchRequest<Note>
        if let tag = selectedTag {
            // 如果有选中的标签，获取所有带有该标签的笔记
            fetchRequest = Note.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isInTrash == NO AND ANY tags == %@", tag)
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        } else {
            // 获取所有笔记
            fetchRequest = Note.fetchAllNotes()
        }
        _notes = FetchRequest(fetchRequest: fetchRequest, animation: .default)
        print("AllNotesView: 初始化完成")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            
            // 笔记列表
            List(selection: $noteViewModel.selectedNote) {
                ForEach(sortedNotes) { note in
                    noteRowView(for: note)
                }
                .onDelete(perform: deleteNote)
            }
            .listStyle(PlainListStyle())
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            print("AllNotesView: onAppear 被调用")
            print("AllNotesView: 笔记数量: \(notes.count)")
            print("AllNotesView: showAllNotes状态: \(folderViewModel.showAllNotes)")
            refreshData()
        }
        .onChange(of: noteViewModel.noteUpdated) { _, _ in
            refreshData()
        }
        .sheet(isPresented: $showMoveSheet) {
            if let moveNote = moveNote {
                NoteMoveTargetSelectionView(note: moveNote)
                    .environmentObject(noteViewModel)
            }
        }
        .sheet(isPresented: $showingSortOptions) {
            sortOptionsSheet
        }
    }
    
    // 顶部栏
    private var topBar: some View {
        HStack(spacing: 16) {
            // 返回按钮
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    onBack()
                }
            }) {
                HStack(spacing: 4) {
                    SwiftUI.Image(systemName: "chevron.left")
                        .font(.body)
                    Text("返回")
                        .lineLimit(1)
                }
                .foregroundColor(.blue)
            }
            .padding(.leading)
            
            Spacer()
            
            // 标题
            Text(selectedTag != nil ? "标签: \(selectedTag!.wrappedName)" : "全部笔记")
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()
            
            // 右侧操作按钮
            HStack(spacing: 16) {
                // 排序按钮
                Button(action: {
                    showingSortOptions = true
                }) {
                    HStack(spacing: 4) {
                        SwiftUI.Image(systemName: sortOption.systemImage)
                            .font(.body)
                            .foregroundColor(.blue)
                        SwiftUI.Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.trailing)
        }
        .padding(.vertical, 8)
        .overlay(
            // 添加高亮提示标签
            Group {
                if noteViewModel.highlightedNoteID != nil {
                    HStack {
                        SwiftUI.Image(systemName: "tag.fill")
                            .foregroundColor(.orange)
                        Text("已定位到标签相关笔记")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .transition(.opacity)
                    .offset(y: 30)
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: noteViewModel.highlightedNoteID != nil)
    }
    
    // 排序选项弹窗
    private var sortOptionsSheet: some View {
        NavigationView {
            List {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                        showingSortOptions = false
                    } label: {
                        HStack {
                            SwiftUI.Image(systemName: option.systemImage)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text(option.rawValue)
                            Spacer()
                            if sortOption == option {
                                SwiftUI.Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("排序方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingSortOptions = false
                    }
                }
            }
        }
    }
    
    // 单个笔记行视图
    private func noteRowView(for note: Note) -> some View {
        VStack {
            Button(action: {
                // 在全部笔记视图中点击笔记时，直接设置选中的笔记
                withAnimation(.easeInOut(duration: 0.3)) {
                    noteViewModel.setSelectedNote(note)
                }
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    // 使用现有的NoteRow，但添加文件夹信息
                    NoteRow(note: note)
                        .environmentObject(noteViewModel)
                    
                    // 显示笔记所属的文件夹
                    if let folder = note.folder {
                        HStack {
                            SwiftUI.Image(systemName: "folder.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("在 \(folder.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                noteViewModel.deleteNote(note: note)
            } label: {
                Label("删除", systemImage: "trash")
            }
            
            Button {
                showMoveNoteSheet(note)
            } label: {
                Label("移动", systemImage: "folder")
            }
            .tint(.blue)
        }
    }
    
    // 显示笔记移动面板
    private func showMoveNoteSheet(_ note: Note) {
        moveNote = note
        showMoveSheet = true
    }
    
    // 刷新数据方法
    private func refreshData() {
        // 刷新数据逻辑
    }
    
    // 删除笔记方法
    private func deleteNote(at offsets: IndexSet) {
        for index in offsets {
            let note = sortedNotes[index]
            noteViewModel.deleteNote(note: note)
        }
    }
} 