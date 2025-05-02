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
    
    // 获取按更新时间排序的笔记数组
    public var notesArray: [Note] {
        let set = notes as? Set<Note> ?? []
        return set.sorted { $0.updatedAt ?? Date() > $1.updatedAt ?? Date() }
    }
}

extension Folder {
    // 获取基本的 fetchRequest
    static func fetchRequest() -> NSFetchRequest<Folder> {
        return NSFetchRequest<Folder>(entityName: "Folder")
    }
    
    // 获取所有文件夹，按名称排序
    static func allFoldersFetchRequest() -> NSFetchRequest<Folder> {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        return request
    }
} 