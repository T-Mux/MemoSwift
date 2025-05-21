//
//  TrashView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/21/25.
//

import SwiftUI
import CoreData

struct TrashView: View {
    @ObservedObject var trashViewModel: TrashViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showEmptyTrashAlert = false
    @State private var itemToRestore: Any? = nil
    @State private var itemToDelete: Any? = nil
    @State private var showRestoreAlert = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            trashContentView
                .listStyle(InsetGroupedListStyle())
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        emptyTrashButton
                    }
                }
                .navigationTitle("回收站")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: trashViewModel.trashUpdated) { _, _ in
                    // 刷新视图
                    viewContext.refreshAllObjects()
                }
                // 清空回收站确认提示
                .alert("清空回收站", isPresented: $showEmptyTrashAlert) {
                    Button("取消", role: .cancel) { }
                    Button("清空", role: .destructive) {
                        trashViewModel.emptyTrash()
                    }
                } message: {
                    Text("此操作将永久删除回收站中的所有项目，不可恢复。")
                }
                // 恢复项目确认提示
                .alert("恢复项目", isPresented: $showRestoreAlert) {
                    Button("取消", role: .cancel) { 
                        itemToRestore = nil
                    }
                    Button("恢复") {
                        restoreItem()
                    }
                } message: {
                    restoreAlertMessage
                }
                // 永久删除确认提示
                .alert("永久删除", isPresented: $showDeleteAlert) {
                    Button("取消", role: .cancel) { 
                        itemToDelete = nil
                    }
                    Button("删除", role: .destructive) {
                        deleteItem()
                    }
                } message: {
                    deleteAlertMessage
                }
        }
    }
    
    // 拆分出回收站内容视图
    private var trashContentView: some View {
        List {
            // 回收站中的文件夹
            foldersSection
            
            // 回收站中的笔记
            notesSection
        }
    }
    
    // 拆分出文件夹部分
    private var foldersSection: some View {
        Section(header: Text("文件夹").font(.headline)) {
            let deletedFolders = trashViewModel.fetchDeletedFolders()
            if deletedFolders.isEmpty {
                Text("没有已删除的文件夹")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(deletedFolders) { folder in
                    folderRow(folder)
                }
            }
        }
    }
    
    // 拆分出笔记部分
    private var notesSection: some View {
        Section(header: Text("笔记").font(.headline)) {
            let deletedNotes = trashViewModel.fetchDeletedNotes()
            if deletedNotes.isEmpty {
                Text("没有已删除的笔记")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(deletedNotes) { note in
                    noteRow(note)
                }
            }
        }
    }
    
    // 单个文件夹行
    private func folderRow(_ folder: Folder) -> some View {
        HStack {
            SwiftUI.Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.headline)
                
                if let createdAt = folder.createdAt {
                    Text("创建于 \(formattedDate(date: createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 恢复按钮
            Button(action: {
                itemToRestore = folder
                showRestoreAlert = true
            }) {
                SwiftUI.Image(systemName: "arrow.uturn.left.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal, 4)
            
            // 永久删除按钮
            Button(action: {
                itemToDelete = folder
                showDeleteAlert = true
            }) {
                SwiftUI.Image(systemName: "trash.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
    
    // 单个笔记行
    private func noteRow(_ note: Note) -> some View {
        HStack {
            SwiftUI.Image(systemName: "doc.text.fill")
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "无标题" : note.title)
                    .font(.headline)
                
                if let updatedAt = note.updatedAt {
                    Text("更新于 \(formattedDate(date: updatedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 恢复按钮
            Button(action: {
                itemToRestore = note
                showRestoreAlert = true
            }) {
                SwiftUI.Image(systemName: "arrow.uturn.left.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal, 4)
            
            // 永久删除按钮
            Button(action: {
                itemToDelete = note
                showDeleteAlert = true
            }) {
                SwiftUI.Image(systemName: "trash.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
    
    // 清空回收站按钮
    private var emptyTrashButton: some View {
        Button(action: {
            if trashViewModel.getTrashItemCount() > 0 {
                showEmptyTrashAlert = true
            }
        }) {
            Text("清空")
                .foregroundColor(.red)
        }
        .disabled(trashViewModel.getTrashItemCount() == 0)
    }
    
    // 恢复提示消息
    private var restoreAlertMessage: Text {
        if let note = itemToRestore as? Note {
            return Text("确定要恢复笔记「\(note.title.isEmpty ? "无标题" : note.title)」吗？")
        } else if let folder = itemToRestore as? Folder {
            return Text("确定要恢复文件夹「\(folder.name)」吗？")
        } else {
            return Text("确定要恢复此项目吗？")
        }
    }
    
    // 删除提示消息
    private var deleteAlertMessage: Text {
        if let note = itemToDelete as? Note {
            return Text("确定要永久删除笔记「\(note.title.isEmpty ? "无标题" : note.title)」吗？此操作不可恢复。")
        } else if let folder = itemToDelete as? Folder {
            return Text("确定要永久删除文件夹「\(folder.name)」吗？此操作不可恢复。")
        } else {
            return Text("确定要永久删除此项目吗？此操作不可恢复。")
        }
    }
    
    // 恢复项目
    private func restoreItem() {
        if let note = itemToRestore as? Note {
            trashViewModel.restoreNote(note: note)
        } else if let folder = itemToRestore as? Folder {
            trashViewModel.restoreFolder(folder: folder)
        }
        itemToRestore = nil
    }
    
    // 删除项目
    private func deleteItem() {
        if let note = itemToDelete as? Note {
            trashViewModel.permanentlyDeleteNote(note: note)
        } else if let folder = itemToDelete as? Folder {
            trashViewModel.permanentlyDeleteFolder(folder: folder)
        }
        itemToDelete = nil
    }
    
    // 格式化日期
    private func formattedDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 