//
//  NoteViewModel.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import Foundation
import CoreData
import SwiftUI

class NoteViewModel: ObservableObject {
    private var viewContext: NSManagedObjectContext
    
    // 当前选中的笔记
    @Published var selectedNote: Note?
    
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
        return newNote
    }
    
    // 更新笔记内容
    func updateNote(note: Note, title: String, content: String) {
        note.title = title
        note.content = content
        note.updatedAt = Date()
        
        saveContext()
    }
    
    // 移动笔记到其他文件夹
    func moveNote(note: Note, toFolder: Folder) {
        note.folder = toFolder
        note.updatedAt = Date()
        
        saveContext()
    }
    
    // 删除笔记
    func deleteNote(note: Note) {
        viewContext.delete(note)
        saveContext()
        
        // 如果删除的是当前选中的笔记，则清除选择
        if selectedNote == note {
            selectedNote = nil
        }
    }
    
    // 保存上下文
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("保存上下文时出错: \(nsError), \(nsError.userInfo)")
        }
    }
} 