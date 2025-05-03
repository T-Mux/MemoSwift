//
//  FolderRow.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI

struct FolderRow: View {
    let folder: Folder
    let folderViewModel: FolderViewModel
    var onRename: () -> Void
    var onMove: () -> Void
    var onDelete: () -> Void
    
    @State private var isShowingMenu = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.headline)
                
                HStack {
                    Text("\(folder.notesArray.count) 条笔记")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let createdDate = folder.createdAt {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(createdDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 子文件夹指示器
            if let childFolders = folder.childFolders, childFolders.count > 0 {
                Text("\(childFolders.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 确保整行都可点击
        .onTapGesture {
            withAnimation(.navigationPush) {
                folderViewModel.selectedFolder = folder
            }
        }
        .transition(.slide)
        .contextMenu {
            // 上下文菜单
            Button(action: onRename) {
                Label("重命名", systemImage: "pencil")
            }
            
            Button(action: onMove) {
                Label("移动", systemImage: "folder.fill.badge.plus")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
        .onLongPressGesture {
            // 触发菜单显示
            isShowingMenu = true
        }
        .actionSheet(isPresented: $isShowingMenu) {
            ActionSheet(
                title: Text("文件夹操作"),
                message: Text("选择对文件夹 \"\(folder.name)\" 的操作"),
                buttons: [
                    .default(Text("重命名")) {
                        onRename()
                    },
                    .default(Text("移动")) {
                        onMove()
                    },
                    .destructive(Text("删除")) {
                        onDelete()
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
} 