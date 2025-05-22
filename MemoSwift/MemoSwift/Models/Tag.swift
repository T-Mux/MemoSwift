import Foundation
import CoreData
import UIKit

@objc(Tag)
public class Tag: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var notes: NSSet?
    
    // 获取ID（防止空值）
    public var wrappedID: UUID {
        id ?? UUID()
    }
    
    // 获取标签名（防止空值）
    public var wrappedName: String {
        name
    }
    
    // 获取关联的笔记数组
    public var notesArray: [Note] {
        let set = notes ?? []
        return set.compactMap { $0 as? Note }.sorted {
            $0.updatedAt ?? Date() > $1.updatedAt ?? Date()
        }
    }
}

extension Tag {
    // 获取基本的 fetchRequest
    static func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }
    
    // 获取特定笔记的标签
    static func fetchRequestForNote(note: Note) -> NSFetchRequest<Tag> {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "ANY notes == %@", note)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        return request
    }
    
    // 添加笔记到标签
    func addNote(_ note: Note) {
        let notes = self.notes?.mutableCopy() as? NSMutableSet ?? NSMutableSet()
        notes.add(note)
        self.notes = notes
    }
} 