//
//  NoteRow.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI
import UIKit

struct NoteRow: View {
    // 使用ObservedObject而不是let，以便自动刷新
    @ObservedObject var note: Note
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isShowingMenu = false
    @State private var showMoveSheet = false
    @State private var showDeleteConfirmation = false
    
    // 引入NoteViewModel，以便可以删除和移动笔记
    @EnvironmentObject private var noteViewModel: NoteViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题显示
            Text(note.wrappedTitle.isEmpty ? "无标题" : note.wrappedTitle)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
            
            HStack(alignment: .top, spacing: 8) {
                // 内容预览
                Text(note.wrappedContent.isEmpty ? "没有内容" : note.wrappedContent.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.trailing, 4)
                
                Spacer()
                
                // 更新日期
                Text(note.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 确保整行都可点击
        .onTapGesture {
            // 点击选择笔记，使用导航推送动画
            withAnimation(.navigationPush) {
                noteViewModel.selectedNote = note
            }
        }
        // 添加适合手势滑动的转换效果
        .transition(.slide)
        .onLongPressGesture {
            // 长按显示操作菜单
            isShowingMenu = true
        }
        // 添加高亮效果
        .background(
            isHighlighted ? Color.blue.opacity(0.15) : Color.clear
        )
        .cornerRadius(4)
        // 添加高亮时的动画效果
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        .contentTransition(.interpolate) // 更平滑的内容更新过渡效果
        .contextMenu {
            // 上下文菜单支持（右键菜单）
            Button(action: {
                showMoveSheet = true
            }) {
                Label("移动", systemImage: "folder")
            }
            
            Button(action: {
                shareNote()
            }) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                Label("删除", systemImage: "trash")
            }
        }
        .actionSheet(isPresented: $isShowingMenu) {
            ActionSheet(
                title: Text("笔记操作"),
                message: Text("选择对笔记 \"\(note.wrappedTitle.isEmpty ? "无标题" : note.wrappedTitle)\" 的操作"),
                buttons: [
                    .default(Text("移动")) {
                        showMoveSheet = true
                    },
                    .default(Text("分享")) {
                        shareNote()
                    },
                    .destructive(Text("删除")) {
                        showDeleteConfirmation = true
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
        .sheet(isPresented: $showMoveSheet) {
            NoteMoveTargetSelectionView(note: note)
                .environmentObject(noteViewModel)
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            .tint(.blue)
            Button("删除", role: .destructive) {
                noteViewModel.deleteNote(note: note)
            }
        } message: {
            Text("确定要删除笔记 \"\(note.wrappedTitle.isEmpty ? "无标题" : note.wrappedTitle)\" 吗？此操作无法撤销。")
        }
    }
    
    // 检查当前笔记是否需要高亮显示
    private var isHighlighted: Bool {
        if let highlightedID = noteViewModel.highlightedNoteID,
           let noteID = note.id {
            return highlightedID == noteID
        }
        return false
    }
    
    // 分享笔记功能
    private func shareNote() {
        let noteContent = "标题：\(note.wrappedTitle)\n\n\(note.wrappedContent)"
        let activityVC = UIActivityViewController(activityItems: [noteContent], applicationActivities: nil)
        
        // 获取当前视图控制器来呈现分享界面
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
} 