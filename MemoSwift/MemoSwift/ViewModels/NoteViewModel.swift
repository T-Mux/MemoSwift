//
//  NoteViewModel.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import Foundation
import CoreData
import SwiftUI
import Combine

class NoteViewModel: ObservableObject {
    private var viewContext: NSManagedObjectContext
    
    // 当前选中的笔记
    @Published var selectedNote: Note?
    // 笔记更新触发器，用于通知列表视图刷新
    @Published var noteUpdated = UUID()
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    // 创建新笔记
    @discardableResult
    func createNote(title: String, content: String, folder: Folder) -> Note {
        let newNote = Note(context: viewContext)
        newNote.id = UUID()
        newNote.title = title
        newNote.content = content
        newNote.createdAt = Date()
        newNote.updatedAt = Date()
        newNote.folder = folder
        
        saveContext()
        // 通知刷新
        noteUpdated = UUID()
        return newNote
    }
    
    // 更新笔记内容
    func updateNote(note: Note, title: String, content: String) {
        // 只有当内容真正改变时才更新
        if note.title != title || note.content != content {
            note.title = title
            note.content = content
            note.updatedAt = Date()
            
            saveContext()
            // 通知刷新
            noteUpdated = UUID()
        }
    }
    
    // 移动笔记到其他文件夹
    func moveNote(note: Note, toFolder: Folder) {
        note.folder = toFolder
        note.updatedAt = Date()
        
        saveContext()
        // 通知刷新
        noteUpdated = UUID()
    }
    
    // 删除笔记
    func deleteNote(note: Note) {
        viewContext.delete(note)
        saveContext()
        
        // 如果删除的是当前选中的笔记，则清除选择
        if selectedNote == note {
            selectedNote = nil
        }
        
        // 通知刷新
        noteUpdated = UUID()
    }
    
    // 强制刷新 - 可以从外部调用以刷新视图
    func forceRefresh() {
        noteUpdated = UUID()
    }
    
    // 保存上下文
    private func saveContext() {
        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        } catch {
            let nsError = error as NSError
            print("保存上下文时出错: \(nsError), \(nsError.userInfo)")
        }
    }
} 