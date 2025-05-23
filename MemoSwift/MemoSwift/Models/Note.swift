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
            print("Note: 开始加载富文本内容，数据大小: \(data.count) 字节")
            
            do {
                // 首先尝试RTFD格式加载
                let attributedString = try NSAttributedString(
                    data: data, 
                    options: [.documentType: NSAttributedString.DocumentType.rtfd], 
                    documentAttributes: nil
                )
                
                print("Note: 成功加载RTFD格式，内容长度: \(attributedString.length)")
                
                // 修复图片附件的显示问题
                let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
                var imageCount = 0
                
                // 检查并修复图片附件
                mutableAttributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableAttributedString.length), options: []) { value, range, _ in
                    if let attachment = value as? NSTextAttachment {
                        imageCount += 1
                        print("Note: 处理第\(imageCount)个图片附件，位置: \(range)")
                        
                        // 如果图片为空但有contents数据，尝试重新创建图片
                        if attachment.image == nil && attachment.contents != nil {
                            if let imageData = attachment.contents,
                               let image = UIImage(data: imageData) {
                                attachment.image = image
                                
                                // 重新设置合适的图片大小
                                let maxWidth: CGFloat = 300.0  // 使用固定的最大宽度
                                let scale = min(maxWidth / image.size.width, 1.0)
                                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                                attachment.bounds = CGRect(origin: .zero, size: newSize)
                                
                                print("Note: 成功修复图片附件，尺寸: \(newSize)")
                            } else {
                                print("Note: 警告 - 无法从附件数据重新创建图片")
                            }
                        } else if attachment.image != nil {
                            // 确保现有图片有合适的尺寸
                            if let image = attachment.image {
                                let maxWidth: CGFloat = 300.0
                                let scale = min(maxWidth / image.size.width, 1.0)
                                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                                
                                // 只有当尺寸明显不合适时才调整
                                if attachment.bounds.size.width <= 0 || attachment.bounds.size.width > maxWidth * 1.2 {
                                    attachment.bounds = CGRect(origin: .zero, size: newSize)
                                    print("Note: 调整图片附件尺寸: \(newSize)")
                                }
                            }
                        } else {
                            print("Note: 警告 - 图片附件无图片且无数据")
                        }
                    }
                }
                
                print("Note: 处理完成，共\(imageCount)个图片附件")
                return mutableAttributedString
                
            } catch {
                print("Note: RTFD加载失败: \(error)")
                // 如果RTFD格式加载失败，尝试RTF格式
                do {
                    let attributedString = try NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                    )
                    print("Note: RTF格式加载成功，长度: \(attributedString.length)")
                    return attributedString
                } catch {
                    print("Note: RTF加载也失败: \(error)")
                }
            }
        }
        
        // 如果没有富文本内容或者无法解析，则返回普通文本并设置默认字体大小为18pt
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body).withSize(18)
        ]
        let fallbackText = NSAttributedString(string: wrappedContent, attributes: defaultAttributes)
        print("Note: 使用默认文本内容，长度: \(fallbackText.length)")
        return fallbackText
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