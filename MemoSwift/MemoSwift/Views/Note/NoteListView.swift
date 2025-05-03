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
                        withAnimation(.navigationPop) {
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
                        Button(action: {
                            withAnimation(.navigationPush) {
                                noteViewModel.selectedNote = note
                            }
                        }) {
                            NoteRow(note: note)
                                .tag(note)
                                .environmentObject(noteViewModel)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.slide)
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
        // 笔记移动面板
        .sheet(isPresented: $showMoveSheet) {
            if let moveNote = moveNote {
                NoteMoveTargetSelectionView(note: moveNote)
                    .environmentObject(noteViewModel)
            }
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