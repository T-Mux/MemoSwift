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
    private var viewContext: NSManagedObjectContext
    
    // 当前选中的笔记
    @Published var selectedNote: Note?
    // 笔记更新触发器，用于通知列表视图刷新
    @Published var noteUpdated = UUID()
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    // 设置选中笔记，确保清除旧的选择状态
    func setSelectedNote(_ note: Note?) {
        // 先清除选中状态，确保视图完全刷新
        self.selectedNote = nil
        
        // 使用微小的延迟确保UI状态更新
        DispatchQueue.main.async {
            if let note = note {
                // 刷新笔记数据确保最新状态
                self.viewContext.refresh(note, mergeChanges: true)
            }
            
            // 设置新的选中笔记
            self.selectedNote = note
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
        
        note.title = title
        
        // 将富文本内容转换为普通文本保存
        note.content = attributedContent.string
        
        // 保存富文本内容
        do {
            let rtfdData = try attributedContent.data(
                from: NSRange(location: 0, length: attributedContent.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            note.richContent = rtfdData
        } catch {
            print("保存富文本内容出错: \(error)")
            // 失败则只保存普通文本
            note.content = attributedContent.string
        }
        
        note.updatedAt = Date()
        saveContext()
        noteUpdated = UUID()
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
        viewContext.delete(note)
        saveContext()
        
        // 如果删除的是当前选中的笔记，则清除选择
        if selectedNote == note {
            selectedNote = nil
        }
        
        // 通知刷新
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
    private func saveContext() {
        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        } catch {
            let nsError = error as NSError
            print("保存上下文时出错: \(nsError), \(nsError.userInfo)")
        }
    }
} 