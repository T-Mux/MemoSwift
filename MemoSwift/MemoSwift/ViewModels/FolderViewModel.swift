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
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    // 创建新文件夹
    func createFolder(name: String) {
        let newFolder = Folder(context: viewContext)
        newFolder.id = UUID()
        newFolder.name = name
        newFolder.createdAt = Date()
        
        saveContext()
    }
    
    // 更新文件夹名称
    func updateFolder(folder: Folder, name: String) {
        folder.name = name
        saveContext()
    }
    
    // 删除文件夹
    func deleteFolder(folder: Folder) {
        viewContext.delete(folder)
        saveContext()
        
        // 如果删除的是当前选中的文件夹，则清除选择
        if selectedFolder == folder {
            selectedFolder = nil
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