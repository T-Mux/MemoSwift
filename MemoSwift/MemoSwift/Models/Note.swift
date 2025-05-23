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
                // 首先尝试RTFD格式加载
                let attributedString = try NSAttributedString(
                    data: data, 
                    options: [.documentType: NSAttributedString.DocumentType.rtfd], 
                    documentAttributes: nil
                )
                
                // 修正图片附件的尺寸
                return correctImageAttachmentSizes(attributedString)
                
            } catch {
                // 如果RTFD格式加载失败，尝试RTF格式
                do {
                    let attributedString = try NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                    )
                    return correctImageAttachmentSizes(attributedString)
                } catch {
                    print("富文本内容加载失败: \(error)")
                }
            }
        }
        
        // 如果没有富文本内容或者无法解析，则返回普通文本并设置默认字体大小为18pt
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body).withSize(18)
        ]
        return NSAttributedString(string: wrappedContent, attributes: defaultAttributes)
    }
    
    // 修正图片附件的尺寸，确保它们适合屏幕宽度
    private func correctImageAttachmentSizes(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        
        // 使用与插入时相同的更保守计算逻辑
        let screenWidth = UIScreen.main.bounds.width
        let maxWidth = min(screenWidth * 0.4, 160.0) // 更小：40%屏幕宽度，最大160px
        let minWidth: CGFloat = 100
        
        print("=== Note加载时图片尺寸修正 ===")
        print("屏幕宽度: \(screenWidth)")
        print("计算最大宽度: \(maxWidth)")
        
        mutableAttributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableAttributedString.length), options: []) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                var originalSize: CGSize
                var imageToProcess: UIImage?
                
                // 获取原始图片和尺寸
                if let image = attachment.image {
                    originalSize = image.size
                    imageToProcess = image
                } else if let contents = attachment.contents, contents.count > 0 {
                    // 如果没有图片但有数据，从数据创建图片
                    if let image = UIImage(data: contents) {
                        originalSize = image.size
                        imageToProcess = image
                        print("从数据恢复图片，原始尺寸: \(originalSize)")
                    } else {
                        return // 无法处理的附件
                    }
                } else {
                    return // 无法处理的附件
                }
                
                guard let sourceImage = imageToProcess else { return }
                
                // 使用与插入时相同的尺寸计算逻辑
                let targetWidth = min(max(maxWidth, minWidth), originalSize.width)
                let scale = targetWidth / originalSize.width
                let targetSize = CGSize(
                    width: targetWidth,
                    height: originalSize.height * scale
                )
                
                // 检查是否需要调整尺寸
                let currentBounds = attachment.bounds
                let needsResize = abs(currentBounds.width - targetSize.width) > 1.0 || 
                                abs(currentBounds.height - targetSize.height) > 1.0
                
                print("图片检查 - 原始:\(originalSize) 目标:\(targetSize) 当前bounds:\(currentBounds) 需要调整:\(needsResize)")
                
                if needsResize {
                    // 重新创建适配屏幕的图片
                    let adaptedImage = createAdaptedImage(sourceImage, targetSize: targetSize)
                    
                    // 更新附件的图片和边界
                    attachment.image = adaptedImage
                    attachment.bounds = CGRect(origin: .zero, size: targetSize)
                    
                    print("图片尺寸修正: \(originalSize) -> \(targetSize)")
                } else {
                    print("图片尺寸已正确: \(targetSize)")
                }
            }
        }
        
        return mutableAttributedString
    }
    
    // 创建适配屏幕的图片
    private func createAdaptedImage(_ originalImage: UIImage, targetSize: CGSize) -> UIImage {
        // 使用与RichTextEditor相同的图片渲染逻辑
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(UIScreen.main.scale, 2.0) // 限制scale以平衡质量和性能
        format.opaque = false // 支持透明背景
        format.preferredRange = .standard
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        
        return renderer.image { context in
            // 设置高质量插值
            context.cgContext.interpolationQuality = .high
            context.cgContext.setShouldAntialias(true)
            context.cgContext.setAllowsAntialiasing(true)
            
            // 绘制图片到目标尺寸
            originalImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
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