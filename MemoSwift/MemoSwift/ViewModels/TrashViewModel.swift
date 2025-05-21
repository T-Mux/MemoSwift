//
//  TrashViewModel.swift
//  MemoSwift
//
//  Created by T-Mux on 5/21/25.
//

import Foundation
import CoreData
import SwiftUI

class TrashViewModel: ObservableObject {
    private var viewContext: NSManagedObjectContext
    @Published var trashUpdated = UUID()
    
    // 引用其他视图模型，用于委托一些操作
    weak var folderViewModel: FolderViewModel?
    weak var noteViewModel: NoteViewModel?
    
    init(viewContext: NSManagedObjectContext, folderViewModel: FolderViewModel? = nil, noteViewModel: NoteViewModel? = nil) {
        self.viewContext = viewContext
        self.folderViewModel = folderViewModel
        self.noteViewModel = noteViewModel
    }
    
    // 获取所有已删除的笔记
    func fetchDeletedNotes() -> [Note] {
        if let noteVM = noteViewModel {
            return noteVM.fetchDeletedNotes()
        } else {
            let fetchRequest = Note.fetchRequestForDeletedNotes()
            do {
                return try viewContext.fetch(fetchRequest)
            } catch {
                print("获取已删除笔记时出错: \(error)")
                return []
            }
        }
    }
    
    // 获取所有已删除的文件夹
    func fetchDeletedFolders() -> [Folder] {
        if let folderVM = folderViewModel {
            return folderVM.fetchDeletedFolders()
        } else {
            let fetchRequest = Folder.deletedFoldersFetchRequest()
            do {
                return try viewContext.fetch(fetchRequest)
            } catch {
                print("获取已删除文件夹时出错: \(error)")
                return []
            }
        }
    }
    
    // 恢复已删除的笔记
    func restoreNote(note: Note) {
        if let noteVM = noteViewModel {
            noteVM.restoreNote(note: note)
        } else {
            note.isInTrash = false
            note.updatedAt = Date()
            saveContext()
        }
        trashUpdated = UUID()
    }
    
    // 恢复已删除的文件夹
    func restoreFolder(folder: Folder) {
        if let folderVM = folderViewModel {
            folderVM.restoreFolder(folder: folder)
        } else {
            folder.isInTrash = false
            
            // 如果有父文件夹且父文件夹已删除，则将父文件夹也恢复
            if let parentFolder = folder.parentFolder, parentFolder.isInTrash {
                restoreFolder(folder: parentFolder)
            }
            
            saveContext()
        }
        trashUpdated = UUID()
    }
    
    // 永久删除笔记
    func permanentlyDeleteNote(note: Note) {
        if let noteVM = noteViewModel {
            noteVM.permanentlyDeleteNote(note: note)
        } else {
            viewContext.delete(note)
            saveContext()
        }
        trashUpdated = UUID()
    }
    
    // 永久删除文件夹
    func permanentlyDeleteFolder(folder: Folder) {
        if let folderVM = folderViewModel {
            folderVM.permanentlyDeleteFolder(folder: folder)
        } else {
            // 递归删除所有子文件夹
            if let childFolders = folder.childFolders as? Set<Folder> {
                for childFolder in childFolders {
                    permanentlyDeleteFolder(folder: childFolder)
                }
            }
            
            // 删除文件夹本身
            viewContext.delete(folder)
            saveContext()
        }
        trashUpdated = UUID()
    }
    
    // 清空回收站
    func emptyTrash() {
        // 首先删除所有已删除的笔记
        let deletedNotes = fetchDeletedNotes()
        for note in deletedNotes {
            permanentlyDeleteNote(note: note)
        }
        
        // 然后删除所有已删除的文件夹
        let deletedFolders = fetchDeletedFolders()
        for folder in deletedFolders {
            permanentlyDeleteFolder(folder: folder)
        }
        
        trashUpdated = UUID()
    }
    
    // 获取回收站中项目的数量
    func getTrashItemCount() -> Int {
        return fetchDeletedNotes().count + fetchDeletedFolders().count
    }
    
    // 强制刷新
    func forceRefresh() {
        trashUpdated = UUID()
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