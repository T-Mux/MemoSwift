//
//  NoteMoveTargetSelectionView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI
import CoreData

struct NoteMoveTargetSelectionView: View {
    let note: Note
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var noteViewModel: NoteViewModel
    
    // 使用State存储加载的文件夹
    @State private var allFolders: [Folder] = []
    @State private var selectedFolder: Folder?
    @State private var searchText = ""
    @State private var isLoading = true
    
    // 跟踪展开状态的字典
    @State private var expandedFolders: [UUID: Bool] = [:]
    
    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return allFolders
        } else {
            return allFolders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // 根文件夹（没有父文件夹的）
    var rootFolders: [Folder] {
        return filteredFolders.filter { $0.parentFolder == nil }
    }
    
    // 返回特定父文件夹下的所有子文件夹
    func childFolders(of parent: Folder) -> [Folder] {
        return filteredFolders.filter { $0.parentFolder == parent }
    }
    
    // 加载所有文件夹
    private func loadFolders() {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        do {
            allFolders = try viewContext.fetch(fetchRequest)
            print("DEBUG: 加载了 \(allFolders.count) 个文件夹")
            
            // 打印根文件夹
            let roots = allFolders.filter { $0.parentFolder == nil }
            print("DEBUG: 根文件夹数量: \(roots.count)")
            for folder in roots {
                print("DEBUG: 根文件夹: \(folder.name)")
            }
            
            isLoading = false
            
            // 初始选择适当的文件夹
            if let current = note.folder, current.parentFolder == nil {
                // 如果当前文件夹是根文件夹，不预选择
                self.selectedFolder = nil
                print("DEBUG: 当前文件夹是根文件夹，不预选")
            } else if let parent = note.folder?.parentFolder {
                // 默认选择父文件夹
                self.selectedFolder = parent
                print("DEBUG: 默认选择父文件夹: \(parent.name)")
            } else if !rootFolders.isEmpty {
                // 默认选择第一个根文件夹
                self.selectedFolder = rootFolders.first
                print("DEBUG: 默认选择第一个根文件夹: \(rootFolders.first?.name ?? "unknown")")
            }
        } catch {
            print("ERROR: 加载文件夹出错: \(error)")
            isLoading = false
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题和搜索栏
                VStack(spacing: 0) {
                    // 自定义标题和工具栏
                    HStack {
                        Button("取消") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("移动笔记")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("移动") {
                            if let targetFolder = selectedFolder {
                                noteViewModel.moveNote(note: note, toFolder: targetFolder)
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        .foregroundColor(selectedFolder == nil ? .gray : .blue)
                        .disabled(selectedFolder == nil)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // 当前笔记信息提示
                    VStack(alignment: .leading, spacing: 4) {
                        Text("笔记：\(note.wrappedTitle.isEmpty ? "无标题" : note.wrappedTitle)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let folder = note.folder {
                            Text("当前位置：\(folder.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    
                    // 搜索栏
                    NoteSearchBar(text: $searchText, placeholder: "搜索文件夹")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                Divider()
                
                // 文件夹列表
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if isLoading {
                            // 加载中指示器
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        } else if rootFolders.isEmpty {
                            Text("没有可用的文件夹")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            // 显示根文件夹及其子文件夹
                            ForEach(rootFolders) { folder in
                                folderRow(folder: folder, level: 0)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
            .edgesIgnoringSafeArea(.bottom)
            .onAppear {
                // 视图出现时加载文件夹
                print("DEBUG: NoteMoveTargetSelectionView onAppear")
                if let folder = note.folder {
                    print("DEBUG: 当前笔记所在文件夹: \(folder.name)")
                } else {
                    print("DEBUG: 笔记没有关联文件夹!")
                }
                loadFolders()
            }
        }
    }
    
    // 递归构建文件夹行，支持层级折叠
    @ViewBuilder
    func folderRow(folder: Folder, level: Int) -> some View {
        let hasChildren = childFolders(of: folder).count > 0
        let isExpanded = expandedFolders[folder.id ?? UUID()] ?? false
        
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                if hasChildren {
                    // 如果有子文件夹，则切换展开状态
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if let id = folder.id {
                            expandedFolders[id] = !(expandedFolders[id] ?? false)
                        }
                    }
                }
                // 不管是否有子文件夹，都可以选择当前文件夹
                selectedFolder = folder
            }) {
                HStack(spacing: 10) {
                    // 缩进，根据层级增加缩进
                    if level > 0 {
                        Spacer()
                            .frame(width: CGFloat(level) * 20)
                    }
                    
                    // 文件夹图标，如果有子文件夹则显示折叠/展开图标
                    if hasChildren {
                        SwiftUI.Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .frame(width: 12, height: 12)
                    } else {
                        // 为保持对齐，没有子文件夹时添加空白
                        Spacer()
                            .frame(width: 12, height: 12)
                    }
                    
                    SwiftUI.Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20, height: 20)
                    
                    Text(folder.name)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if selectedFolder == folder {
                        SwiftUI.Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(selectedFolder == folder ? Color(.systemGray6) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            
            // 子文件夹 - 修复递归问题
            if hasChildren && isExpanded {
                ForEach(childFolders(of: folder)) { childFolder in
                    // 使用子文件夹行组件而不是递归调用
                    ChildFolderRow(
                        folder: childFolder,
                        level: level + 1,
                        selectedFolder: $selectedFolder,
                        expandedFolders: $expandedFolders,
                        childFoldersProvider: childFolders
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}

// 子文件夹行组件，避免自引用
struct ChildFolderRow: View {
    let folder: Folder
    let level: Int
    @Binding var selectedFolder: Folder?
    @Binding var expandedFolders: [UUID: Bool]
    let childFoldersProvider: (Folder) -> [Folder]
    
    var body: some View {
        let hasChildren = childFoldersProvider(folder).count > 0
        let isExpanded = expandedFolders[folder.id ?? UUID()] ?? false
        
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                if hasChildren {
                    // 如果有子文件夹，则切换展开状态
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if let id = folder.id {
                            expandedFolders[id] = !(expandedFolders[id] ?? false)
                        }
                    }
                }
                // 不管是否有子文件夹，都可以选择当前文件夹
                selectedFolder = folder
            }) {
                HStack(spacing: 10) {
                    // 缩进，根据层级增加缩进
                    Spacer()
                        .frame(width: CGFloat(level) * 20)
                    
                    // 文件夹图标，如果有子文件夹则显示折叠/展开图标
                    if hasChildren {
                        SwiftUI.Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .frame(width: 12, height: 12)
                    } else {
                        // 为保持对齐，没有子文件夹时添加空白
                        Spacer()
                            .frame(width: 12, height: 12)
                    }
                    
                    SwiftUI.Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20, height: 20)
                    
                    Text(folder.name)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if selectedFolder == folder {
                        SwiftUI.Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(selectedFolder == folder ? Color(.systemGray6) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
            
            // 子文件夹
            if hasChildren && isExpanded {
                ForEach(childFoldersProvider(folder)) { childFolder in
                    ChildFolderRow(
                        folder: childFolder,
                        level: level + 1,
                        selectedFolder: $selectedFolder,
                        expandedFolders: $expandedFolders,
                        childFoldersProvider: childFoldersProvider
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}

// 自定义搜索栏组件
struct NoteSearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            SwiftUI.Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    SwiftUI.Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
} 