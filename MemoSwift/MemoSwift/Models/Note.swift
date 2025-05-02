//
//  Note.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import Foundation
import CoreData

@objc(Note)
public class Note: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String
    @NSManaged public var content: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var folder: Folder?
    
    // 获取标题（防止空值）
    public var wrappedTitle: String {
        title
    }
    
    // 获取内容（防止空值）
    public var wrappedContent: String {
        content ?? ""
    }
    
    // 格式化日期显示
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt ?? Date())
    }
}

extension Note {
    // 获取基本的 fetchRequest
    static func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note")
    }
    
    // 获取特定文件夹下的笔记，按更新时间降序排列
    static func fetchRequestForFolder(folder: Folder) -> NSFetchRequest<Note> {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "folder == %@", folder)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        return request
    }
} 