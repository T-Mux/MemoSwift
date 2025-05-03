//
//  Folder.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import Foundation
import CoreData

@objc(Folder)
public class Folder: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var notes: NSSet?
    @NSManaged public var parentFolder: Folder?
    @NSManaged public var childFolders: NSSet?
    
    // 获取按更新时间排序的笔记数组
    public var notesArray: [Note] {
        let set = notes as? Set<Note> ?? []
        return set.sorted { $0.updatedAt ?? Date() > $1.updatedAt ?? Date() }
    }
    
    // 获取按名称排序的子文件夹数组
    public var childFoldersArray: [Folder] {
        let set = childFolders as? Set<Folder> ?? []
        return set.sorted { $0.name < $1.name }
    }
    
    // 判断是否为根文件夹（没有父文件夹）
    public var isRootFolder: Bool {
        return parentFolder == nil
    }
    
    // 获取完整路径名称
    public var fullPath: String {
        if let parent = parentFolder {
            return "\(parent.fullPath)/\(name)"
        }
        return name
    }
}

extension Folder {
    // 获取基本的 fetchRequest
    static func fetchRequest() -> NSFetchRequest<Folder> {
        return NSFetchRequest<Folder>(entityName: "Folder")
    }
    
    // 获取所有根文件夹，按名称排序
    static func allFoldersFetchRequest() -> NSFetchRequest<Folder> {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "parentFolder == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        return request
    }
    
    // 获取特定父文件夹下的子文件夹
    static func childFoldersFetchRequest(parent: Folder) -> NSFetchRequest<Folder> {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "parentFolder == %@", parent)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        return request
    }
} 