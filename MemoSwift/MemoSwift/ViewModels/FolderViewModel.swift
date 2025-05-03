//
//  FolderViewModel.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import Foundation
import CoreData
import SwiftUI

class FolderViewModel: ObservableObject {
    private var viewContext: NSManagedObjectContext
    
    // 当前选中的文件夹
    @Published var selectedFolder: Folder?
    // 文件夹更新触发器
    @Published var folderUpdated = UUID()
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    // 创建新文件夹（可选指定父文件夹）
    func createFolder(name: String, parentFolder: Folder? = nil) {
        let newFolder = Folder(context: viewContext)
        newFolder.id = UUID()
        newFolder.name = name
        newFolder.createdAt = Date()
        newFolder.parentFolder = parentFolder
        
        saveContext()
        folderUpdated = UUID()
    }
    
    // 更新文件夹名称
    func renameFolder(folder: Folder, newName: String) {
        if folder.name != newName && !newName.isEmpty {
            folder.name = newName
            saveContext()
            folderUpdated = UUID()
        }
    }
    
    // 移动文件夹到新的父文件夹
    func moveFolder(folder: Folder, toParent: Folder?) {
        // 检查是否试图将文件夹移动到自己的子文件夹中（这会创建循环引用）
        if let newParent = toParent {
            var current = newParent
            while let parent = current.parentFolder {
                if parent == folder {
                    print("错误：不能将文件夹移动到其子文件夹中")
                    return
                }
                current = parent
            }
        }
        
        folder.parentFolder = toParent
        saveContext()
        folderUpdated = UUID()
    }
    
    // 删除文件夹及其所有内容（包括子文件夹和笔记）
    func deleteFolder(folder: Folder) {
        // 递归删除所有子文件夹
        if let childFolders = folder.childFolders as? Set<Folder> {
            for childFolder in childFolders {
                deleteFolder(folder: childFolder)
            }
        }
        
        // 删除文件夹本身
        viewContext.delete(folder)
        saveContext()
        
        // 如果删除的是当前选中的文件夹，则清除选择
        if selectedFolder == folder {
            selectedFolder = nil
        }
        
        folderUpdated = UUID()
    }
    
    // 获取所有可移动到的目标文件夹（排除当前文件夹及其子文件夹）
    func getAvailableTargetFolders(forFolder folder: Folder) -> [Folder] {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            let allFolders = try viewContext.fetch(fetchRequest)
            
            // 排除当前文件夹及其所有子文件夹
            return allFolders.filter { targetFolder in
                if targetFolder == folder {
                    return false
                }
                
                // 检查是否是当前文件夹的子文件夹
                var current = targetFolder
                while let parent = current.parentFolder {
                    if parent == folder {
                        return false
                    }
                    current = parent
                }
                
                return true
            }
        } catch {
            print("获取文件夹列表出错: \(error)")
            return []
        }
    }
    
    // 强制刷新
    func forceRefresh() {
        folderUpdated = UUID()
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