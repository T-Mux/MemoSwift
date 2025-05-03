//
//  MoveTargetSelectionView.swift
//  MemoSwift
//
//  Created by T-Mux on 6/11/25.
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
            VStack {
                List(selection: $selectedTarget) {
                    // 特殊选项：移动到根目录
                    Button(action: {
                        selectedTarget = nil
                    }) {
                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundColor(.blue)
                            Text("根目录")
                                .foregroundColor(.primary)
                            Spacer()
                            
                            if selectedTarget == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Section("可用文件夹") {
                        if filteredFolders.isEmpty {
                            Text("没有可移动的目标文件夹")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredFolders) { folder in
                                Button(action: {
                                    selectedTarget = folder
                                }) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.blue)
                                        
                                        VStack(alignment: .leading) {
                                            Text(folder.name)
                                                .foregroundColor(.primary)
                                            
                                            if let parent = folder.parentFolder {
                                                Text("在 \(parent.name) 中")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedTarget == folder {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .searchable(text: $searchText, prompt: "搜索文件夹")
            }
            .navigationTitle(folderToMove != nil ? "移动\"\(folderToMove!.name)\"" : "移动文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("移动", action: onConfirm)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
} 