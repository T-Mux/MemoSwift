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
    
    init(folder: Folder, noteViewModel: NoteViewModel, onBack: @escaping () -> Void) {
        self.folder = folder
        self.noteViewModel = noteViewModel
        self.onBack = onBack
        
        let fetchRequest = Note.fetchRequestForFolder(folder: folder)
        _notes = FetchRequest(fetchRequest: fetchRequest, animation: .default)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
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
                    
                    // 右侧：添加按钮菜单
                    Menu {
                        // 添加新笔记
                        Button(action: {
                            let newNote = noteViewModel.createNote(
                                title: "",
                                content: "",
                                folder: folder
                            )
                            noteViewModel.selectedNote = newNote
                        }) {
                            Label("新建笔记", systemImage: "square.and.pencil")
                        }
                        
                        // OCR文字识别
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
            
            Divider()
            
            // 笔记列表
            List(selection: $noteViewModel.selectedNote) {
                ForEach(notes) { note in
                    Button(action: {
                        noteViewModel.selectedNote = note
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
                .onDelete(perform: deleteNote)
            }
            .listStyle(PlainListStyle())
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // 当视图出现时，重新获取数据
            refreshData()
        }
        .onChange(of: noteViewModel.noteUpdated) { _, _ in
            // 笔记更新时刷新数据
            refreshData()
        }
        // 笔记移动面板
        .sheet(isPresented: $showMoveSheet) {
            if let moveNote = moveNote {
                NoteMoveTargetSelectionView(note: moveNote)
                    .environmentObject(noteViewModel)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        // OCR 视图
        .sheet(isPresented: $showOCRView) {
            OCRView(noteViewModel: noteViewModel, folder: folder)
        }
    }
    
    // 显示笔记移动面板
    private func showMoveNoteSheet(_ note: Note) {
        moveNote = note
        showMoveSheet = true
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
