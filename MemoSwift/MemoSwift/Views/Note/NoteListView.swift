//
//  NoteListView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI
import CoreData

struct NoteListView: View {
    let folder: Folder
    @ObservedObject var noteViewModel: NoteViewModel
    var onBack: () -> Void  // 新增返回回调
    
    @FetchRequest private var notes: FetchedResults<Note>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showMoveSheet = false
    @State private var moveNote: Note?
    @State private var showOCRView = false // 新增OCR视图状态
    @State private var selectedTag: Tag?
    @State private var showingTagFilter = false
    
    init(folder: Folder, noteViewModel: NoteViewModel, onBack: @escaping () -> Void, selectedTag: Tag? = nil) {
        self.folder = folder
        self.noteViewModel = noteViewModel
        self.onBack = onBack
        self.selectedTag = selectedTag

        let fetchRequest: NSFetchRequest<Note>
        if let tag = selectedTag {
            fetchRequest = Note.fetchRequestForFolderAndTag(folder: folder, tag: tag)
        } else {
            fetchRequest = Note.fetchRequestForFolder(folder: folder)
        }
        _notes = FetchRequest(fetchRequest: fetchRequest, animation: .default)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            // 笔记列表
            List(selection: $noteViewModel.selectedNote) {
                ForEach(notes) { note in
                    noteRowView(for: note)
                }
                .onDelete(perform: deleteNote)
            }
            .listStyle(PlainListStyle())
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
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
        .sheet(isPresented: $showOCRView) {
            OCRView(noteViewModel: noteViewModel, folder: folder)
        }
        .sheet(isPresented: $showingTagFilter) {
            tagFilterSheet
        }
    }
    
    // 顶部栏提取为独立属性
    private var topBar: some View {
        ZStack {
            Text(folder.name)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack {
                Button(action: {
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        SwiftUI.Image(systemName: "chevron.left")
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
                Button(action: {
                    showingTagFilter = true
                }) {
                    HStack {
                        SwiftUI.Image(systemName: "tag")
                        if let tag = selectedTag {
                            Text(tag.wrappedName)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(selectedTag != nil ? .blue : .gray)
                }
                .padding(.trailing)
                Menu {
                    Button(action: {
                        let newNote = noteViewModel.createNote(
                            title: "",
                            content: "",
                            folder: folder
                        )
                        noteViewModel.setSelectedNote(newNote)
                    }) {
                        Label("新建笔记", systemImage: "square.and.pencil")
                    }
                    Button(action: {
                        showOCRView = true
                    }) {
                        Label("OCR文字识别", systemImage: "text.viewfinder")
                    }
                } label: {
                    SwiftUI.Image(systemName: "plus")
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
    }
    
    // 标签过滤弹窗提取为独立属性
    private var tagFilterSheet: some View {
        NavigationView {
            List {
                Button(action: {
                    selectedTag = nil
                    showingTagFilter = false
                }) {
                    HStack {
                        Text("显示所有笔记")
                        Spacer()
                        if selectedTag == nil {
                            SwiftUI.Image(systemName: "checkmark")
                        }
                    }
                }
                ForEach(noteViewModel.fetchAllTags(), id: \.id) { tag in
                    Button {
                        selectTagAndUpdateNoteList(tag)
                        showingTagFilter = false
                    } label: {
                        HStack {
                            Text(tag.wrappedName)
                            Spacer()
                            if isSelectedTag(tag) {
                                SwiftUI.Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("按标签过滤")
        }
    }
    
    // 将单个笔记行提取为独立的视图函数，简化主视图体
    private func noteRowView(for note: Note) -> some View {
        Button(action: {
            noteViewModel.setSelectedNote(note)
        }) {
            NoteRow(note: note)
                .tag(note)
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
        // 如果有选中的标签，重新应用标签过滤
        // if let selectedTag = selectedTag {
        //     let fetchRequest = Note.fetchRequestForFolderAndTag(folder: folder, tag: selectedTag)
        //     notes.nsPredicate = fetchRequest.predicate
        //     notes.nsSortDescriptors = fetchRequest.sortDescriptors ?? []
        // }
    }
    
    // 删除笔记方法
    private func deleteNote(at offsets: IndexSet) {
        for index in offsets {
            let note = notes[index]
            noteViewModel.deleteNote(note: note)
        }
    }
    
    private func selectTagAndUpdateNoteList(_ tag: Tag) {
        selectedTag = tag
        // let fetchRequest = Note.fetchRequestForFolderAndTag(folder: folder, tag: tag)
        // notes.nsPredicate = fetchRequest.predicate
        // notes.nsSortDescriptors = fetchRequest.sortDescriptors ?? []
    }
    
    private func isSelectedTag(_ tag: Tag) -> Bool {
        selectedTag?.id == tag.id
    }
}
