//
//  NoteMoveTargetSelectionView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI

struct NoteMoveTargetSelectionView: View {
    let note: Note
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var noteViewModel: NoteViewModel
    
    // 获取所有文件夹
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.name, ascending: true)],
        animation: .default
    ) private var allFolders: FetchedResults<Folder>
    
    @State private var selectedFolder: Folder?
    @State private var searchText = ""
    
    // 跟踪展开状态的字典
    @State private var expandedFolders: [UUID: Bool] = [:]
    
    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return Array(allFolders)
        } else {
            return allFolders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // 根文件夹（没有父文件夹的）
    var rootFolders: [Folder] {
        filteredFolders.filter { $0.parentFolder == nil }
    }
    
    // 返回特定父文件夹下的所有子文件夹
    func childFolders(of parent: Folder) -> [Folder] {
        return filteredFolders.filter { $0.parentFolder == parent }
    }
    
    var body: some View {
        NavigationView {
            List {
                // 显示根文件夹及其子文件夹
                ForEach(rootFolders) { folder in
                    folderRow(folder: folder, level: 0)
                }
            }
            .searchable(text: $searchText, prompt: "搜索文件夹")
            .navigationTitle("移动笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("移动") {
                        if let targetFolder = selectedFolder {
                            noteViewModel.moveNote(note: note, toFolder: targetFolder)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(selectedFolder == nil)
                }
            }
        }
    }
    
    // 递归构建文件夹行，支持层级折叠
    @ViewBuilder
    func folderRow(folder: Folder, level: Int) -> some View {
        let hasChildren = childFolders(of: folder).count > 0
        let isExpanded = expandedFolders[folder.id ?? UUID()] ?? false
        
        VStack(spacing: 0) {
            Button(action: {
                if hasChildren {
                    // 如果有子文件夹，则切换展开状态
                    withAnimation(.standardNavigation) {
                        if let id = folder.id {
                            expandedFolders[id] = !(expandedFolders[id] ?? false)
                        }
                    }
                }
                // 不管是否有子文件夹，都可以选择当前文件夹
                selectedFolder = folder
            }) {
                HStack {
                    // 缩进，根据层级增加缩进
                    if level > 0 {
                        Spacer()
                            .frame(width: CGFloat(level) * 20)
                    }
                    
                    // 文件夹图标，如果有子文件夹则显示折叠/展开图标
                    if hasChildren {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                    
                    Text(folder.name)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if selectedFolder == folder {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .contentShape(Rectangle())
            
            // 子文件夹
            if hasChildren && isExpanded {
                ForEach(childFolders(of: folder)) { childFolder in
                    // 非递归调用，直接内联
                    let childHasChildren = childFolders(of: childFolder).count > 0
                    let childIsExpanded = expandedFolders[childFolder.id ?? UUID()] ?? false
                    
                    VStack(spacing: 0) {
                        Button(action: {
                            if childHasChildren {
                                withAnimation(.standardNavigation) {
                                    if let id = childFolder.id {
                                        expandedFolders[id] = !(expandedFolders[id] ?? false)
                                    }
                                }
                            }
                            selectedFolder = childFolder
                        }) {
                            HStack {
                                // 增加缩进
                                Spacer()
                                    .frame(width: CGFloat(level + 1) * 20)
                                
                                if childHasChildren {
                                    Image(systemName: childIsExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                Image(systemName: "folder")
                                    .foregroundColor(.blue)
                                
                                Text(childFolder.name)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedFolder == childFolder {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        
                        // 对于二级子文件夹，我们显示一个"更多..."按钮，而不是递归
                        if childHasChildren && childIsExpanded {
                            Button(action: {
                                selectedFolder = childFolder
                            }) {
                                HStack {
                                    Spacer()
                                        .frame(width: CGFloat(level + 2) * 20)
                                    
                                    Text("更多...")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
} 