//
//  Note.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import Foundation
import CoreData
import UIKit

@objc(Note)
public class Note: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String
    @NSManaged public var content: String?
    @NSManaged public var richContent: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var isInTrash: Bool
    @NSManaged public var folder: Folder?
    @NSManaged public var images: NSSet?
    @NSManaged public var tags: NSSet?
    @NSManaged public var reminders: NSSet?
    
    // 获取标题（防止空值）
    public var wrappedTitle: String {
        title
    }
    
    // 获取内容（防止空值）
    public var wrappedContent: String {
        content ?? ""
    }
    
    // 获取富文本内容
    public var wrappedRichContent: NSAttributedString {
        if let data = richContent {
            do {
                // 修复：移除字符编码选项，RTFD格式会自动处理编码
                let attributedString = try NSAttributedString(
                    data: data, 
                    options: [.documentType: NSAttributedString.DocumentType.rtfd], 
                    documentAttributes: nil
                )
                return attributedString
            } catch {
                print("加载富文本内容出错: \(error)")
                // 如果富文本加载失败，尝试加载为RTF格式
                do {
                    let attributedString = try NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                    )
                    return attributedString
                } catch {
                    print("RTF加载也失败: \(error)")
                }
            }
        }
        
        // 如果没有富文本内容或者无法解析，则返回普通文本并设置默认字体大小为18pt
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body).withSize(18)
        ]
        return NSAttributedString(string: wrappedContent, attributes: defaultAttributes)
    }
    
    // 获取图片数组
    public var imagesArray: [Image] {
        let set = images ?? []
        return set.compactMap { $0 as? Image }.sorted {
            $0.wrappedCreatedAt < $1.wrappedCreatedAt
        }
    }
    
    // 获取标签数组
    public var tagsArray: [Tag] {
        let set = tags ?? []
        return set.compactMap { $0 as? Tag }.sorted {
            $0.wrappedName < $1.wrappedName
        }
    }
    
    // 获取提醒数组
    public var remindersArray: [Reminder] {
        let set = reminders ?? []
        return set.compactMap { $0 as? Reminder }.sorted {
            ($0.reminderDate ?? Date()) < ($1.reminderDate ?? Date())
        }
    }
    
    // 获取活动提醒数组
    public var activeRemindersArray: [Reminder] {
        return remindersArray.filter { $0.isActive }
    }
    
    // 格式化日期显示
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt ?? Date())
    }
    
    // 检查是否有活动提醒
    public var hasActiveReminders: Bool {
        return activeRemindersArray.count > 0
    }
    
    // 获取最近的提醒
    public var nextReminder: Reminder? {
        let now = Date()
        let activeReminders = activeRemindersArray.filter { $0.reminderDate != nil && $0.reminderDate! >= now }
        return activeReminders.first
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
        request.predicate = NSPredicate(format: "folder == %@ AND isInTrash == NO", folder)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        return request
    }
    
    // 获取特定文件夹和标签下的笔记，按更新时间降序排列
    static func fetchRequestForFolderAndTag(folder: Folder, tag: Tag) -> NSFetchRequest<Note> {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "folder == %@ AND ANY tags == %@ AND isInTrash == NO", folder, tag)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        return request
    }
    
    // 获取已删除的笔记
    static func fetchRequestForDeletedNotes() -> NSFetchRequest<Note> {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        return request
    }
    
    // 获取有活动提醒的笔记
    static func fetchNotesWithActiveReminders() -> NSFetchRequest<Note> {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == NO AND ANY reminders.isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        return request
    }
    
    // 获取所有笔记（不包括回收站中的）
    static func fetchAllNotes() -> NSFetchRequest<Note> {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "isInTrash == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        return request
    }
    
    // 添加图片到笔记
    func addImage(_ image: Image) {
        let images = self.images?.mutableCopy() as? NSMutableSet ?? NSMutableSet()
        images.add(image)
        self.images = images
    }
    
    // 添加标签到笔记
    func addTag(_ tag: Tag) {
        let tags = self.tags?.mutableCopy() as? NSMutableSet ?? NSMutableSet()
        tags.add(tag)
        self.tags = tags
    }
    
    // 移除特定标签
    func removeTag(_ tag: Tag) {
        let tags = self.tags?.mutableCopy() as? NSMutableSet ?? NSMutableSet()
        tags.remove(tag)
        self.tags = tags
    }
    
    // 检查是否有特定标签
    func hasTag(_ tag: Tag) -> Bool {
        return tagsArray.contains(where: { $0.id == tag.id })
    }
    
    // 添加提醒到笔记
    func addReminder(_ reminder: Reminder) {
        let reminders = self.reminders?.mutableCopy() as? NSMutableSet ?? NSMutableSet()
        reminders.add(reminder)
        self.reminders = reminders
    }
    
    // 移除特定提醒
    func removeReminder(_ reminder: Reminder) {
        let reminders = self.reminders?.mutableCopy() as? NSMutableSet ?? NSMutableSet()
        reminders.remove(reminder)
        self.reminders = reminders
    }
    
    // 刷新提醒状态
    public func refreshReminders(context: NSManagedObjectContext) {
        // 刷新所有提醒对象
        for reminder in remindersArray {
            context.refresh(reminder, mergeChanges: true)
        }
        
        // 刷新当前笔记对象
        context.refresh(self, mergeChanges: true)
    }
} 