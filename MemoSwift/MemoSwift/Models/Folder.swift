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
    @NSManaged public var isInTrash: Bool
    @NSManaged public var notes: NSSet?
    @NSManaged public var parentFolder: Folder?
    @NSManaged public var childFolders: NSSet?
    
    // 获取按更新时间排序的笔记数组（不包含已删除的笔记）
    public var notesArray: [Note] {
        let set = notes as? Set<Note> ?? []
        return set.filter { !$0.isInTrash }.sorted { $0.updatedAt ?? Date() > $1.updatedAt ?? Date() }
    }
    
    // 获取按名称排序的子文件夹数组（不包含已删除的文件夹）
    public var childFoldersArray: [Folder] {
        let set = childFolders as? Set<Folder> ?? []
        return set.filter { !$0.isInTrash }.sorted { $0.name < $1.name }
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
    
    // 获取所有根文件夹的 fetchRequest
    static func allFoldersFetchRequest() -> NSFetchRequest<Folder> {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "parentFolder == nil AND isInTrash == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        return request
    }
    
    // 获取子文件夹的 fetchRequest
    static func childFoldersFetchRequest(for parentFolder: Folder) -> NSFetchRequest<Folder> {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "parentFolder == %@ AND isInTrash == NO", parentFolder)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        return request
    }
    
    // 获取所有已删除文件夹的 fetchRequest
    static func deletedFoldersFetchRequest() -> NSFetchRequest<Folder> {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        return request
    }
} 