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
    @FocusState private var isTitleFocused: Bool
    @State private var canUndo = false
    @State private var canRedo = false
    @State private var showingTagManager = false
    @State private var newTagName = ""
    @State private var availableTags: [Tag] = []
    @State private var selectedTags: [Tag] = []
    @State private var debounceTimer: Timer?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    
    init(note: Note, noteViewModel: NoteViewModel, onBack: @escaping () -> Void) {
        self.note = note
        self.noteViewModel = noteViewModel
        self.onBack = onBack
        
        // 刷新笔记数据，确保使用最新状态
        let context = PersistenceController.shared.container.viewContext
        context.refresh(note, mergeChanges: true)
        
        // 从笔记中获取初始值
        let initialTitle = note.wrappedTitle
        let initialContent = note.wrappedRichContent
        
        // 明确使用刚刚获取的初始值创建State对象
        _title = State(initialValue: initialTitle)
        _attributedContent = State(initialValue: initialContent)
        
        // 初始化标签
        let fetchedTags = noteViewModel.fetchTagsForNote(note: note)
        _selectedTags = State(initialValue: fetchedTags)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            titleField
            Divider()
            imagesSection
            tagManagementSection
            richTextEditorSection
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            debounceTimer?.invalidate()
            saveChanges()
            NotificationCenter.default.removeObserver(self)
            noteViewModel.forceRefresh()
        }
        .transition(.move(edge: .trailing))
        .onAppear {
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
            loadNoteTags()
        }
        .sheet(isPresented: $showingTagManager) {
            tagManagerSheet
        }
        .onChange(of: showingTagManager) { _, newValue in
            if !newValue {
                // 关闭标签管理器时，确保不自动弹出富文本编辑器
                focusTextEditor = false
                // 设置一个更长时间的防护，确保标签管理关闭后富文本编辑器不会自动获取焦点
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    focusTextEditor = false
                }
            } else {
                // 打开标签管理器时，同样确保富文本编辑器失去焦点
                focusTextEditor = false
            }
        }
    }
    
    // 顶部导航栏部分
    private var topBar: some View {
        ZStack {
            Text(title.isEmpty ? "新笔记" : title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack {
                Button(action: {
                    debounceTimer?.invalidate()
                    saveChanges()
                    viewContext.refreshAllObjects()
                    noteViewModel.forceRefresh()
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
                HStack(spacing: 16) {
                    Button(action: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RichTextEditorUndo"),
                            object: nil
                        )
                    }) {
                        SwiftUI.Image(systemName: "arrow.uturn.backward")
                            .font(.body)
                            .foregroundColor(canUndo ? .blue : .gray)
                    }
                    .disabled(!canUndo)
                    Button(action: {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RichTextEditorRedo"),
                            object: nil
                        )
                    }) {
                        SwiftUI.Image(systemName: "arrow.uturn.forward")
                            .font(.body)
                            .foregroundColor(canRedo ? .blue : .gray)
                    }
                    .disabled(!canRedo)
                }
                .padding(.trailing)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // 标题输入框部分
    private var titleField: some View {
        TextField("标题", text: $title)
            .font(.title3)
            .padding()
            .background(Color(.systemBackground))
            .focused($isTitleFocused)
            .onTapGesture {
                isTitleFocused = true
                focusTextEditor = false
            }
            .onChange(of: title) { _, _ in
                debounceSave()
            }
            .submitLabel(.done)
            .onSubmit {
                isTitleFocused = false
                focusTextEditor = true
            }
    }
    
    // 图片显示部分
    private var imagesSection: some View {
        Group {
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
        }
    }
    
    // 标签管理区域部分
    private var tagManagementSection: some View {
        HStack {
            Text("标签")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(selectedTags, id: \.id) { tag in
                        tagChip(for: tag)
                    }
                }
            }
            Button(action: {
                showingTagManager = true
                loadNoteTags()
            }) {
                SwiftUI.Image(systemName: "plus.circle")
            }
        }
        .padding()
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
        // 先刷新笔记确保使用最新数据
        viewContext.refresh(note, mergeChanges: true)
        
        // 更新笔记，使用富文本内容
        noteViewModel.updateNoteWithRichContent(
            note: note,
            title: title,
            attributedContent: attributedContent
        )
        
        // 保存完毕后不自动聚焦富文本编辑器
        focusTextEditor = false
    }
    
    // 加载笔记的标签
    private func loadNoteTags() {
        selectedTags = noteViewModel.fetchTagsForNote(note: note)
        availableTags = noteViewModel.fetchAllTags().filter { tag in
            !selectedTags.contains(where: { $0.id == tag.id })
        }
    }
    
    // 单独提取标签chip为函数，简化主视图体，帮助编译器类型检查
    private func tagChip(for tag: Tag) -> some View {
        HStack {
            Text(tag.wrappedName)
                .font(.caption)
            Button(action: {
                noteViewModel.removeTagFromNote(note: note, tag: tag)
                loadNoteTags()
            }) {
                SwiftUI.Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.red)
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }

    // 富文本编辑器部分提取为独立属性，简化主视图体，帮助编译器类型检查
    private var richTextEditorSection: some View {
        // 首先创建一个不会自动获取焦点的编辑器
        let editor = RichTextEditor(
            attributedText: $attributedContent,
            focus: $focusTextEditor,
            canUndo: $canUndo,
            canRedo: $canRedo,
            onCommit: { updatedText in
                self.attributedContent = updatedText
                debounceSave()
            }
        )
        .padding([.horizontal, .top], 8)
        .background(Color(.systemBackground))
        
        // 仅在完全非标签操作上下文中，才考虑自动聚焦
        return editor.onAppear {
            // 首次加载时如果有内容，且不是在标签操作后，才自动聚焦
            if !note.wrappedTitle.isEmpty && 
               !note.wrappedContent.isEmpty && 
               !showingTagManager &&
               !UserDefaults.standard.bool(forKey: "recentTagOperation") {
                
                // 设置一个较长的延迟，确保只有在确实需要的情况下才聚焦
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // 再次检查标记，以防在延迟期间进行了标签操作
                    if !UserDefaults.standard.bool(forKey: "recentTagOperation") {
                        isTitleFocused = false
                        focusTextEditor = true
                    }
                }
            } else {
                // 重置标记，但不聚焦富文本编辑器
                UserDefaults.standard.removeObject(forKey: "recentTagOperation")
            }
        }
    }

    private var tagManagerSheet: some View {
        TagListContainer(
            availableTags: availableTags,
            selectedTags: selectedTags,
            newTagName: $newTagName,
            onAddTag: { tagName in
                _ = noteViewModel.addTagToNote(note: note, tagName: tagName)
                loadNoteTags()
                // 防止富文本功能栏自动弹出
                withAnimation(.none) {
                    focusTextEditor = false
                }
            },
            onRemoveTag: { tag in
                noteViewModel.removeTagFromNote(note: note, tag: tag)
                loadNoteTags()
                // 防止富文本功能栏自动弹出
                withAnimation(.none) {
                    focusTextEditor = false
                }
            },
            onClose: {
                showingTagManager = false
                // 关闭标签管理器后，显式设置为不聚焦
                DispatchQueue.main.async {
                    focusTextEditor = false
                    isTitleFocused = false
                }
            }
        )
    }
}

// TagListContainer to separate tag list from binding issues
struct TagListContainer: View {
    var availableTags: [Tag]
    var selectedTags: [Tag]
    @Binding var newTagName: String
    let onAddTag: (String) -> Void
    let onRemoveTag: (Tag) -> Void
    let onClose: () -> Void
    
    // 防止自动弹出键盘的状态
    @State private var shouldFocusTextField = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("标签管理")
                    .font(.headline)
                    .padding(.top)
                
                // 当前笔记的标签
                if !selectedTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("当前标签")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(selectedTags, id: \.id) { tag in
                                    selectedTagButton(for: tag)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                    .padding(.bottom, 8)
                }
                
                // 可用标签列表
                VStack(alignment: .leading, spacing: 8) {
                    Text("可添加标签")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if availableTags.isEmpty {
                        Text("暂无可添加的标签")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        // 简化视图结构，拆分复杂表达式
                        tagListSection
                    }
                }
                
                // 新建标签区域
                addTagSection
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        // 设置一个标记表示最近进行了标签操作
                        UserDefaults.standard.set(true, forKey: "recentTagOperation")
                        isTextFieldFocused = false
                        // 先关闭键盘
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        // 延迟关闭以确保键盘先收起
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onClose()
                        }
                    }
                }
            }
            .onAppear {
                // 确保不会自动弹出键盘
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    shouldFocusTextField = true
                    isTextFieldFocused = false
                }
            }
            .onDisappear {
                // 视图消失时标记操作完成
                UserDefaults.standard.set(true, forKey: "recentTagOperation")
            }
        }
    }
    
    // 拆分出标签列表部分
    private var tagListSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(availableTags, id: \.id) { tag in
                    tagButton(for: tag)
                }
            }
        }
        .frame(maxHeight: 150)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // 进一步拆分单个标签按钮
    private func tagButton(for tag: Tag) -> some View {
        Button(action: {
            onAddTag(tag.wrappedName)
        }) {
            HStack {
                Text(tag.wrappedName)
                    .foregroundColor(.primary)
                Spacer()
                SwiftUI.Image(systemName: "plus.circle")
                    .foregroundColor(.green)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
        }
    }
    
    // 当前已选标签按钮
    private func selectedTagButton(for tag: Tag) -> some View {
        HStack {
            Text(tag.wrappedName)
                .foregroundColor(.primary)
            Spacer()
            Button(action: {
                onRemoveTag(tag)
            }) {
                SwiftUI.Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    // 拆分添加标签部分
    private var addTagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("新建标签")
                .font(.subheadline)
                .foregroundColor(.secondary)
                
            HStack {
                TextField("输入标签名称", text: $newTagName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onChange(of: shouldFocusTextField) { _, newValue in
                        if newValue {
                            // 显式设置为不聚焦，防止键盘自动弹出
                            isTextFieldFocused = false
                        }
                    }
                
                Button(action: {
                    addNewTag()
                }) {
                    SwiftUI.Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 8)
    }
    
    // 拆分添加标签的动作
    private func addNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // 设置一个标记表示最近进行了标签操作
        UserDefaults.standard.set(true, forKey: "recentTagOperation")
        // 先关闭键盘
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        onAddTag(trimmed)
        newTagName = ""
    }
} 
