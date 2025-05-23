//
//  NoteViewModel.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import Foundation
import CoreData
import SwiftUI
import Combine
import UIKit
import Vision

class NoteViewModel: ObservableObject {
    // 修改为公开属性，允许外部访问
    let viewContext: NSManagedObjectContext
    
    // 当前选中的笔记
    @Published var selectedNote: Note?
    // 笔记更新触发器，用于通知列表视图刷新
    @Published var noteUpdated = UUID()
    // 添加高亮显示的笔记ID，用于在笔记列表中高亮显示特定笔记
    @Published var highlightedNoteID: UUID?
    // 引用文件夹视图模型，用于在点击标签相关笔记时设置选中文件夹
    weak var folderViewModel: FolderViewModel?
    
    init(viewContext: NSManagedObjectContext, folderViewModel: FolderViewModel? = nil) {
        self.viewContext = viewContext
        self.folderViewModel = folderViewModel
    }
    
    // 设置选中笔记，确保清除旧的选择状态
    func setSelectedNote(_ note: Note?) {
        // 先清除选中状态，确保视图完全刷新
        let oldSelectedNote = self.selectedNote
        self.selectedNote = nil
        
        guard let noteToSelect = note else {
            return // 如果传入nil，直接返回，保持选中笔记为nil
        }
        
        // 获取笔记ID
        guard let noteId = noteToSelect.id else {
            print("警告: 试图选择没有ID的笔记")
            return
        }
        
        // 确保不是选择同一个笔记
        if let oldNote = oldSelectedNote, let oldId = oldNote.id, oldId == noteId {
            print("选择的是同一个笔记，直接设置")
            self.selectedNote = noteToSelect
            return
        }
        
        print("准备选择新笔记: \(noteToSelect.wrappedTitle), ID: \(noteId)")
        
        // 使用微小的延迟确保UI状态更新
        DispatchQueue.main.async {
            // 根据ID重新获取笔记对象，确保使用最新的实例
            let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", noteId as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try self.viewContext.fetch(fetchRequest)
                if let freshNote = results.first {
                    // 确保使用最新的笔记对象
                    self.viewContext.refresh(freshNote, mergeChanges: true)
                    // 设置新的选中笔记
                    self.selectedNote = freshNote
                    print("已选择笔记: \(freshNote.wrappedTitle)")
                } else {
                    // 如果找不到笔记，使用原始对象但先刷新
                    self.viewContext.refresh(noteToSelect, mergeChanges: true)
                    self.selectedNote = noteToSelect
                    print("找不到最新笔记对象，使用原始对象: \(noteToSelect.wrappedTitle)")
                }
            } catch {
                // 出错时使用原始对象但先刷新
                print("选择笔记时出错: \(error)")
                self.viewContext.refresh(noteToSelect, mergeChanges: true)
                self.selectedNote = noteToSelect
            }
        }
    }
    
    // 创建新笔记
    @discardableResult
    func createNote(title: String, content: String, folder: Folder) -> Note {
        let newNote = Note(context: viewContext)
        newNote.id = UUID()
        newNote.title = title
        newNote.content = content
        newNote.createdAt = Date()
        newNote.updatedAt = Date()
        newNote.folder = folder
        
        // 创建带有18pt字体的富文本内容
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body).withSize(18)
        ]
        let attributedString = NSAttributedString(string: content, attributes: defaultAttributes)
        
        // 保存富文本内容
        do {
            let rtfdData = try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            newNote.richContent = rtfdData
        } catch {
            print("保存初始富文本内容出错: \(error)")
        }
        
        saveContext()
        // 通知刷新
        noteUpdated = UUID()
        
        // 确保在更新selected之前刷新视图上下文
        viewContext.refresh(newNote, mergeChanges: true)
        
        return newNote
    }
    
    // 更新笔记内容（普通文本）
    func updateNote(note: Note, title: String, content: String) {
        // 只有当内容真正改变时才更新
        if note.title != title || note.content != content {
            note.title = title
            note.content = content
            note.updatedAt = Date()
            
            saveContext()
            // 通知刷新
            noteUpdated = UUID()
        }
    }
    
    // 更新笔记富文本内容
    func updateNoteWithRichContent(note: Note, title: String, attributedContent: NSAttributedString) {
        // 先刷新笔记确保使用最新数据
        viewContext.refresh(note, mergeChanges: true)
        
        // 检查标题是否发生变化
        let titleChanged = note.title != title
        
        // 检查内容是否发生变化
        let contentString = attributedContent.string
        let contentChanged = note.content != contentString
        
        // 检查富文本内容是否发生变化
        var richContentChanged = false
        if let existingRichContent = note.richContent {
            do {
                let existingAttributedString = try NSAttributedString(
                    data: existingRichContent,
                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                    documentAttributes: nil
                )
                richContentChanged = !NSAttributedString.areEqual(existingAttributedString, attributedContent)
            } catch {
                richContentChanged = true
            }
        } else {
            richContentChanged = attributedContent.length > 0
        }
        
        // 只有在内容真正发生变化时才进行更新
        if titleChanged || contentChanged || richContentChanged {
            note.title = title
            note.content = contentString
            
            // 简单保存富文本内容
            do {
                // 检查是否包含图片附件
                var hasImages = false
                attributedContent.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedContent.length), options: []) { value, range, _ in
                    if value is NSTextAttachment {
                        hasImages = true
                    }
                }
                
                // 根据是否有图片选择格式
                let documentType: NSAttributedString.DocumentType = hasImages ? .rtfd : .rtf
                let rtfdData = try attributedContent.data(
                    from: NSRange(location: 0, length: attributedContent.length),
                    documentAttributes: [.documentType: documentType]
                )
                note.richContent = rtfdData
                
            } catch {
                print("保存富文本内容出错: \(error)")
                note.content = attributedContent.string
                note.richContent = nil
            }
            
            note.updatedAt = Date()
            saveContext()
            noteUpdated = UUID()
            print("笔记内容已变化，已更新: \(title)")
        } else {
            print("笔记内容无变化，未更新修改时间: \(title)")
        }
    }
    
    // 添加图片到笔记
    func addImage(to note: Note, imageData: Data) {
        let newImage = Image.createImage(withData: imageData, in: viewContext)
        newImage.note = note
        note.addImage(newImage)
        note.updatedAt = Date()
        
        saveContext()
        noteUpdated = UUID()
    }
    
    // 从图片中提取文本(OCR)
    func performOCR(from imageData: Data, completion: @escaping (String?) -> Void) {
        guard let image = UIImage(data: imageData) else {
            completion(nil)
            return
        }
        
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion(nil)
                return
            }
            
            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(text)
        }
        
        // 配置识别请求参数
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("执行OCR识别失败: \(error)")
            completion(nil)
        }
    }
    
    // 移动笔记到其他文件夹
    func moveNote(note: Note, toFolder: Folder) {
        note.folder = toFolder
        note.updatedAt = Date()
        
        saveContext()
        // 通知刷新
        noteUpdated = UUID()
    }
    
    // 删除笔记
    func deleteNote(note: Note) {
        // 标记为已删除而不是直接删除
        note.isInTrash = true
        note.updatedAt = Date()
        saveContext()
        
        // 如果删除的是当前选中的笔记，则清除选择
        if selectedNote == note {
            selectedNote = nil
        }
        
        // 通知刷新
        noteUpdated = UUID()
    }
    
    // 恢复已删除的笔记
    func restoreNote(note: Note) {
        note.isInTrash = false
        note.updatedAt = Date()
        saveContext()
        noteUpdated = UUID()
    }
    
    // 永久删除笔记
    func permanentlyDeleteNote(note: Note) {
        viewContext.delete(note)
        saveContext()
        
        // 如果删除的是当前选中的笔记，则清除选择
        if selectedNote == note {
            selectedNote = nil
        }
        
        // 通知刷新
        noteUpdated = UUID()
    }
    
    // 获取所有已删除的笔记
    func fetchDeletedNotes() -> [Note] {
        let fetchRequest = Note.fetchRequestForDeletedNotes()
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("获取已删除笔记时出错: \(error)")
            return []
        }
    }
    
    // 清空回收站（永久删除所有已删除的笔记）
    func emptyTrash() {
        let deletedNotes = fetchDeletedNotes()
        for note in deletedNotes {
            viewContext.delete(note)
        }
        saveContext()
        noteUpdated = UUID()
    }
    
    // 强制刷新 - 可以从外部调用以刷新视图
    func forceRefresh() {
        // 确保CoreData上下文内的所有对象都是最新状态
        if let note = selectedNote {
            viewContext.refresh(note, mergeChanges: true)
        }
        noteUpdated = UUID()
    }
    
    // 保存上下文
    func saveContext() {
        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        } catch {
            let nsError = error as NSError
            print("保存上下文时出错: \(nsError), \(nsError.userInfo)")
        }
    }
    
    // 创建新标签
    @discardableResult
    func createTag(name: String) -> Tag {
        let newTag = Tag(context: viewContext)
        newTag.id = UUID()
        newTag.name = name
        newTag.createdAt = Date()
        
        saveContext()
        return newTag
    }
    
    // 为笔记添加标签
    func addTagToNote(note: Note, tagName: String) -> Tag {
        // 先检查是否已存在同名标签
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", tagName)
        var tag: Tag
        do {
            let existingTags = try viewContext.fetch(fetchRequest)
            if let existingTag = existingTags.first {
                tag = existingTag
            } else {
                // 如果不存在，创建新标签
                tag = createTag(name: tagName)
            }
            // 避免重复添加
            if !note.hasTag(tag) {
                note.addTag(tag)
                note.updatedAt = Date()
                saveContext()
                viewContext.refresh(note, mergeChanges: true) // 强制刷新
                noteUpdated = UUID()
                print("添加标签 \(tagName) 到笔记 \(note.title)")
            }
            return tag
        } catch {
            print("查找或创建标签时出错: \(error)")
            // 如果出错，直接创建新标签
            let newTag = createTag(name: tagName)
            note.addTag(newTag)
            note.updatedAt = Date()
            saveContext()
            viewContext.refresh(note, mergeChanges: true) // 强制刷新
            noteUpdated = UUID()
            print("添加标签 \(tagName) 到笔记 \(note.title)")
            return newTag
        }
    }
    
    // 从笔记中移除标签
    func removeTagFromNote(note: Note, tag: Tag) {
        note.removeTag(tag)
        note.updatedAt = Date()
        saveContext()
        noteUpdated = UUID()
    }
    
    // 获取所有标签
    func fetchAllTags() -> [Tag] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("获取所有标签时出错: \(error)")
            return []
        }
    }
    
    // 获取特定笔记的所有标签
    func fetchTagsForNote(note: Note) -> [Tag] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "ANY notes == %@", note)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("获取笔记标签时出错: \(error)")
            return []
        }
    }
    
    // 删除标签
    func deleteTag(_ tag: Tag) {
        viewContext.delete(tag)
        saveContext()
        noteUpdated = UUID()
    }
} 