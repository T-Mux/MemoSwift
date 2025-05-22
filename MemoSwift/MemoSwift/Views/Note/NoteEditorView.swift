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
    @EnvironmentObject var reminderViewModel: ReminderViewModel
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
    @State private var showingReminderList = false
    
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
            reminderSection
            richTextEditorSection
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingImagePicker) {
            PhotoPicker(
                selectedImage: $selectedImage,
                sourceType: imageSource == .camera ? .camera : .photoLibrary,
                onImagePicked: { _ in }
            )
            .onDisappear {
                if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
                    noteViewModel.addImage(to: note, imageData: imageData)
                }
                selectedImage = nil
            }
        }
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
                   let sourceRaw = userInfo["source"] as? String {
                    // 根据字符串确定图片来源
                    let source: PhotoSource = (sourceRaw == "camera") ? .camera : .photoLibrary
                    handleImageRequest(source: source)
                }
            }
            loadNoteTags()
        }
        .sheet(isPresented: $showingTagManager) {
            tagManagerSheet
        }
        .sheet(isPresented: $showingReminderList, onDismiss: {
            // 关闭时重新刷新笔记状态
            note.refreshReminders(context: viewContext)
            viewContext.refresh(note, mergeChanges: true)
            reminderViewModel.reminderUpdated = UUID() // 触发更新
        }) {
            ReminderListView(reminderViewModel: reminderViewModel, note: note)
                .presentationDetents([.medium, .large])
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
        .onReceive(reminderViewModel.$reminderUpdated) { _ in
            // 提醒更新时刷新视图
            viewContext.refresh(note, mergeChanges: true)
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
        .actionSheet(isPresented: $showingImageOptions) {
            ActionSheet(
                title: Text("添加图片"),
                buttons: [
                    .default(Text("相机")) { handleImageRequest(source: .camera) },
                    .default(Text("照片库")) { handleImageRequest(source: .photoLibrary) },
                    .cancel()
                ]
            )
        }
    }
    
    // 标题输入框部分
    private var titleField: some View {
        HStack {
            TextField("标题", text: $title)
                .font(.title2)
                .fontWeight(.bold)
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
            
            // 显示提醒状态
            if note.hasActiveReminders {
                Button(action: {
                    // 刷新提醒状态后再显示列表
                    note.refreshReminders(context: viewContext)
                    showingReminderList = true
                }) {
                    ReminderIndicator(note: note)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // 添加提醒部分
    private var reminderSection: some View {
        HStack {
            Button(action: {
                // 刷新提醒状态后再显示列表
                note.refreshReminders(context: viewContext)
                showingReminderList = true
            }) {
                HStack {
                    SwiftUI.Image(systemName: "bell")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                    
                    Text("提醒")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                    
                    Spacer()
                    
                    if note.hasActiveReminders {
                        Text("\(note.activeRemindersArray.count)")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    
                    SwiftUI.Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(Color(.systemBackground))
        .padding(.vertical, 4)
    }
    
    // 图片显示部分
    private var imagesSection: some View {
        Group {
            if !note.imagesArray.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(note.imagesArray) { imageEntity in
                            NoteImageView(imageData: imageEntity.wrappedData)
                                .frame(height: 120)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
            }
        }
    }
    
    // 标签管理部分
    private var tagManagementSection: some View {
        // 标签管理部分
        HStack {
            // 如果有选中的标签，则显示标签
            if !selectedTags.isEmpty {
                TagScrollView(
                    tags: selectedTags, 
                    onRemove: removeTag, 
                    onAddMore: { showingTagManager = true }
                )
            } else {
                // 如果没有标签，显示"添加标签"按钮
                AddTagButton(action: { showingTagManager = true })
            }
        }
        .background(Color(.systemBackground))
        .padding(.vertical, 4)
    }
    
    // 标签滚动视图组件
    private struct TagScrollView: View {
        let tags: [Tag]
        let onRemove: (Tag) -> Void
        let onAddMore: () -> Void
        
        var body: some View {
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(tags) { tag in
                            TagView(tag: tag, onRemove: onRemove)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 8)
                }
                
                // 添加或管理标签按钮
                Button(action: onAddMore) {
                    SwiftUI.Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // 单个标签视图
    private struct TagView: View {
        let tag: Tag
        let onRemove: (Tag) -> Void
        
        var body: some View {
            HStack(spacing: 6) {
                Text(tag.wrappedName)
                    .font(.system(size: 15))
                    .padding(.leading, 10)
                    .padding(.vertical, 6)
                
                Button(action: { onRemove(tag) }) {
                    SwiftUI.Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
                .padding(.vertical, 6)
            }
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(14)
        }
    }
    
    // 添加标签按钮
    private struct AddTagButton: View {
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    SwiftUI.Image(systemName: "tag")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                    
                    Text("添加标签")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    SwiftUI.Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // 富文本编辑器部分
    private var richTextEditorSection: some View {
        Group {
            RichTextEditor(
                attributedText: $attributedContent,
                focus: $focusTextEditor,
                canUndo: $canUndo,
                canRedo: $canRedo,
                onCommit: { newContent in
                    attributedContent = newContent
                    debounceSave()
                }
            )
            .onChange(of: attributedContent) { _, _ in
                debounceSave()
            }
        }
    }
    
    // 标签管理弹出视图
    private var tagManagerSheet: some View {
        NavigationView {
            VStack {
                // 添加新标签的部分
                HStack {
                    TextField("新标签名称", text: $newTagName)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Button(action: {
                        addNewTag()
                    }) {
                        Text("添加")
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(newTagName.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(newTagName.isEmpty)
                }
                .padding()
                
                Divider()
                
                // 显示可选标签的列表
                List {
                    ForEach(availableTags) { tag in
                        Button(action: {
                            toggleTag(tag)
                        }) {
                            HStack {
                                Text(tag.wrappedName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedTags.contains(where: { $0.id == tag.id }) {
                                    SwiftUI.Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deleteTag(at: indexSet)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("管理标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingTagManager = false
                    }
                }
            }
        }
    }
    
    // 保存笔记变更
    private func saveChanges() {
        // 将当前富文本内容保存回笔记
        noteViewModel.updateNoteWithRichContent(
            note: note,
            title: title,
            attributedContent: attributedContent
        )
    }
    
    // 延迟保存（防止频繁保存）
    private func debounceSave() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            saveChanges()
        }
    }
    
    // 处理图片请求
    private func handleImageRequest(source: PhotoSource) {
        imageSource = source
        showingImagePicker = true
    }
    
    // 加载笔记的标签
    private func loadNoteTags() {
        // 获取已选标签
        selectedTags = noteViewModel.fetchTagsForNote(note: note)
        
        // 获取所有可用标签
        availableTags = noteViewModel.fetchAllTags()
    }
    
    // 添加新标签
    private func addNewTag() {
        guard !newTagName.isEmpty else { return }
        
        // 添加标签到笔记
        let newTag = noteViewModel.addTagToNote(note: note, tagName: newTagName)
        
        // 更新本地标签列表
        if !selectedTags.contains(where: { $0.id == newTag.id }) {
            selectedTags.append(newTag)
        }
        
        // 确保在可用标签列表中
        if !availableTags.contains(where: { $0.id == newTag.id }) {
            availableTags.append(newTag)
        }
        
        // 清空输入框
        newTagName = ""
    }
    
    // 切换标签选择状态
    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            // 如果标签已选中，则取消选择
            selectedTags.remove(at: index)
            noteViewModel.removeTagFromNote(note: note, tag: tag)
        } else {
            // 如果标签未选中，则选中它
            selectedTags.append(tag)
            note.addTag(tag)
            noteViewModel.saveContext()
        }
    }
    
    // 删除标签
    private func deleteTag(at indexSet: IndexSet) {
        for index in indexSet {
            let tagToDelete = availableTags[index]
            
            // 首先从已选标签中移除
            if let selectedIndex = selectedTags.firstIndex(where: { $0.id == tagToDelete.id }) {
                selectedTags.remove(at: selectedIndex)
            }
            
            // 从笔记中移除标签
            noteViewModel.removeTagFromNote(note: note, tag: tagToDelete)
            
            // 删除标签
            noteViewModel.deleteTag(tagToDelete)
            
            // 从可用标签列表中移除
            availableTags.remove(at: index)
        }
    }
    
    // 移除标签
    private func removeTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
            noteViewModel.removeTagFromNote(note: note, tag: tag)
        }
    }
} 
