//
//  NoteEditorView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI
import UIKit
import Vision

struct NoteEditorView: View {
    let note: Note
    @ObservedObject var noteViewModel: NoteViewModel
    var onBack: () -> Void  // 返回回调
    
    @State private var title: String
    @State private var attributedContent: NSAttributedString
    @State private var showingImageOptions = false
    @State private var showingImagePicker = false
    @State private var imageSource: PhotoSource = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var showingOCRView = false
    @State private var focusTextEditor = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    @State private var debounceTimer: Timer?
    
    init(note: Note, noteViewModel: NoteViewModel, onBack: @escaping () -> Void) {
        self.note = note
        self.noteViewModel = noteViewModel
        self.onBack = onBack
        
        _title = State(initialValue: note.wrappedTitle)
        _attributedContent = State(initialValue: note.wrappedRichContent)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏 - 与文件夹界面保持一致的设计，确保标题居中
            ZStack {
                // 居中标题
                Text(title.isEmpty ? "新笔记" : title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                HStack {
                    // 左侧：返回按钮
                    Button(action: {
                        // 返回前确保立即保存当前更改
                        debounceTimer?.invalidate()
                        saveChanges()
                        
                        // 确保数据更新前强制刷新
                        viewContext.refreshAllObjects()
                        noteViewModel.forceRefresh()
                        
                        // 返回上一级（使用导航控制器风格的动画）
                        withAnimation(.navigationPop) {
                            onBack()
                        }
                    }) {
                        HStack(spacing: 4) {
                            SwiftUI.Image(systemName: "chevron.left")
                                .font(.body)
                            Text("返回")
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.leading)
                    
                    Spacer()
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            Divider()
            
            // 标题输入框
            TextField("标题", text: $title)
                .font(.title3)
                .padding()
                .background(Color(.systemBackground))
                .onChange(of: title) { _, _ in
                    debounceSave()
                }
            
            Divider()
            
            // 显示已添加的图片
            if !note.imagesArray.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(note.imagesArray, id: \.wrappedID) { imageEntity in
                            NoteImageView(imageData: imageEntity.wrappedData)
                                .frame(height: 120)
                                .frame(width: 150)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                Divider()
            }
            
            // 富文本编辑器
            RichTextEditor(attributedText: $attributedContent, focus: $focusTextEditor, onCommit: { updatedText in
                self.attributedContent = updatedText
                debounceSave()
            })
            .padding([.horizontal, .top], 8)
            .background(Color(.systemBackground))
            .onAppear {
                // 延迟短暂时间后使文本编辑器获得焦点
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusTextEditor = true
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            // 视图消失时，停止所有计时器并立即保存
            debounceTimer?.invalidate()
            saveChanges()
            
            // 移除通知观察者
            NotificationCenter.default.removeObserver(self)
            
            // 强制刷新确保所有更改可见
            noteViewModel.forceRefresh()
        }
        .transition(.move(edge: .trailing))
        // 监听富文本编辑器的图片请求通知
        .onAppear {
            // 添加通知观察者
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RichTextEditorImageRequest"),
                object: nil,
                queue: .main
            ) { [self] notification in
                if let userInfo = notification.userInfo,
                   let source = userInfo["source"] as? ImageSource {
                    handleImageRequest(source: source)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotoPicker(
                selectedImage: $selectedImage,
                sourceType: imageSource == .camera ? .camera : .photoLibrary,
                onImagePicked: { image in
                    if let imageData = image.jpegData(compressionQuality: 0.7) {
                        noteViewModel.addImage(to: note, imageData: imageData)
                    }
                }
            )
        }
        .sheet(isPresented: $showingOCRView) {
            OCRProcessView(
                onProcessed: { result in
                    // 处理OCR结果
                    handleOCRResult(result)
                    showingOCRView = false
                },
                onDismiss: {
                    showingOCRView = false
                }
            )
        }
    }
    
    // 处理富文本编辑器的图片请求
    private func handleImageRequest(source: ImageSource) {
        // 确保我们使用的是正确的枚举类型
        switch source {
        case .camera:
            imageSource = .camera
            showingImagePicker = true
        case .photoLibrary:
            imageSource = .photoLibrary
            showingImagePicker = true
        case .ocr:
            showingOCRView = true
        }
    }
    
    // 处理OCR结果
    private func handleOCRResult(_ result: OCRResult) {
        // 保存图片
        if let imageData = result.image.jpegData(compressionQuality: 0.7) {
            noteViewModel.addImage(to: note, imageData: imageData)
        }
        
        // 将识别出的文本添加到当前笔记内容中
        if !result.text.isEmpty {
            // 创建一个新的可变属性字符串
            let currentText = attributedContent.string
            let newText = currentText.isEmpty ? result.text : "\n\n\(result.text)"
            
            let mutableAttributedString = NSMutableAttributedString(attributedString: attributedContent)
            let textToAdd = NSAttributedString(string: newText)
            mutableAttributedString.append(textToAdd)
            
            attributedContent = mutableAttributedString
            debounceSave()
        }
    }
    
    // 延迟保存 - 使用计时器防抖
    private func debounceSave() {
        // 取消已有的计时器
        debounceTimer?.invalidate()
        
        // 创建新的计时器，延迟0.5秒后保存（缩短延迟时间提高响应性）
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            saveChanges()
        }
    }
    
    // 保存所有更改
    private func saveChanges() {
        // 更新笔记，使用富文本内容
        noteViewModel.updateNoteWithRichContent(
            note: note,
            title: title,
            attributedContent: attributedContent
        )
    }
} 