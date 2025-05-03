//
//  NoteEditorView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI

struct NoteEditorView: View {
    let note: Note
    @ObservedObject var noteViewModel: NoteViewModel
    var onBack: () -> Void  // 返回回调
    
    @State private var title: String
    @State private var content: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    @State private var debounceTimer: Timer?
    
    init(note: Note, noteViewModel: NoteViewModel, onBack: @escaping () -> Void) {
        self.note = note
        self.noteViewModel = noteViewModel
        self.onBack = onBack
        
        _title = State(initialValue: note.wrappedTitle)
        _content = State(initialValue: note.wrappedContent)
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
                            Image(systemName: "chevron.left")
                                .font(.body)
                            Text("返回")
                                .font(.body)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.leading)
                    .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                    
                    // 右侧：预留空间保持对称
                    Spacer()
                        .frame(width: 100)
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
            
            // 内容输入区
            TextEditor(text: $content)
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color(.systemBackground))
                .onChange(of: content) { _, _ in
                    debounceSave()
                }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            // 视图消失时，停止所有计时器并立即保存
            debounceTimer?.invalidate()
            saveChanges()
            
            // 强制刷新确保所有更改可见
            noteViewModel.forceRefresh()
        }
        .transition(.move(edge: .trailing))
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
        // 仅当内容有变化时才更新
        if note.title != title || note.content != content {
            noteViewModel.updateNote(
                note: note,
                title: title,
                content: content
            )
            
            // 强制保存并刷新
            try? viewContext.save()
        }
    }
} 