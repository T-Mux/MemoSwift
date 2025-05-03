//
//  MoveTargetSelectionView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/3/25.
//

import SwiftUI

struct MoveTargetSelectionView: View {
    let folderToMove: Folder?
    let availableTargets: [Folder]
    @Binding var selectedTarget: Folder?
    var onCancel: () -> Void
    var onConfirm: () -> Void
    
    @State private var searchText = ""
    
    var filteredFolders: [Folder] {
        if searchText.isEmpty {
            return availableTargets
        } else {
            return availableTargets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题和搜索栏
                VStack(spacing: 0) {
                    // 自定义标题和工具栏
                    HStack {
                        Button("取消", action: onCancel)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(folderToMove != nil ? "移动\"\(folderToMove!.name)\"" : "移动文件夹")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("移动", action: onConfirm)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // 提示信息
                    if let folder = folderToMove {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("文件夹：\(folder.name)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let parent = folder.parentFolder {
                                Text("当前位置：\(parent.name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("当前位置：根目录")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                    }
                    
                    // 搜索栏
                    FolderSearchBar(text: $searchText, placeholder: "搜索文件夹")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                Divider()
                
                // 文件夹列表
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 特殊选项：移动到根目录
                        Button(action: {
                            selectedTarget = nil
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "house.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 20, height: 20)
                                
                                Text("根目录")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedTarget == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .background(selectedTarget == nil ? Color(.systemGray6) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        
                        // 可用文件夹标题
                        Text("可用文件夹")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                        
                        if filteredFolders.isEmpty {
                            Text("没有可移动的目标文件夹")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(filteredFolders) { folder in
                                Button(action: {
                                    selectedTarget = folder
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.blue)
                                            .frame(width: 20, height: 20)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(folder.name)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            if let parent = folder.parentFolder {
                                                Text("在 \(parent.name) 中")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedTarget == folder {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal)
                                    .background(selectedTarget == folder ? Color(.systemGray6) : Color.clear)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// 自定义搜索栏组件
struct FolderSearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
} 