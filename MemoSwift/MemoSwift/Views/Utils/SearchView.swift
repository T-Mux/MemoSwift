//
//  SearchView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/4/25.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    @ObservedObject var noteViewModel: NoteViewModel
    @ObservedObject var folderViewModel: FolderViewModel
    
    @State private var showCancelButton: Bool = false
    @State private var isEditing: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    // 搜索图标和文本框
                    HStack {
                        SwiftUI.Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                        
                        TextField("搜索笔记", text: $searchViewModel.searchQuery)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(8)
                            .onSubmit {
                                searchViewModel.performSearch()
                            }
                            .submitLabel(.search)
                            .onChange(of: searchViewModel.searchQuery) { _, _ in
                                showCancelButton = !searchViewModel.searchQuery.isEmpty
                                searchViewModel.performSearch()
                            }
                            .onTapGesture {
                                isEditing = true
                            }
                        
                        // 清除按钮
                        if !searchViewModel.searchQuery.isEmpty {
                            Button(action: {
                                searchViewModel.searchQuery = ""
                                searchViewModel.resetSearch()
                            }) {
                                SwiftUI.Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // 取消按钮
                    if isEditing || showCancelButton {
                        Button("取消") {
                            isEditing = false
                            searchViewModel.searchQuery = ""
                            searchViewModel.resetSearch()
                            hideKeyboard()
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.blue)
                        .padding(.trailing)
                        .transition(.move(edge: .trailing))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .animation(.default, value: isEditing || showCancelButton)
                
                // 搜索建议
                if !searchViewModel.searchSuggestions.isEmpty && searchViewModel.searchQuery.count >= 2 {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(searchViewModel.searchSuggestions, id: \.self) { suggestion in
                            Button(action: {
                                if suggestion.hasPrefix("全文搜索: ") {
                                    // 切换到全文搜索
                                    searchViewModel.searchMode = .fullText
                                    searchViewModel.performSearch()
                                } else if suggestion.hasPrefix("#") {
                                    // 标签搜索
                                    let tagName = String(suggestion.dropFirst())
                                    searchViewModel.searchQuery = tagName
                                    searchViewModel.searchMode = .tag
                                    searchViewModel.performSearch()
                                } else {
                                    // 直接使用建议
                                    searchViewModel.searchQuery = suggestion
                                    searchViewModel.performSearch()
                                }
                            }) {
                                HStack {
                                    SwiftUI.Image(systemName: suggestion.hasPrefix("#") ? "tag" : 
                                                 (suggestion.hasPrefix("全文搜索: ") ? "doc.text.magnifyingglass" : "magnifyingglass"))
                                        .foregroundColor(.gray)
                                    
                                    Text(suggestion)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                                .padding(.leading)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                    .padding(.horizontal)
                }
                
                // 搜索结果视图
                SearchResultsView(
                    searchViewModel: searchViewModel,
                    noteViewModel: noteViewModel
                )
                .onChange(of: noteViewModel.selectedNote) { _, note in
                    if note != nil {
                        // 当选中笔记时关闭搜索页面
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onDisappear {
                // 视图消失时重置搜索状态
                searchViewModel.resetSearch()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            searchViewModel.searchMode = .quick
                            searchViewModel.performSearch()
                        }) {
                            Label("快速搜索", systemImage: "magnifyingglass")
                                .foregroundColor(searchViewModel.searchMode == .quick ? .blue : .primary)
                        }
                        
                        Button(action: {
                            searchViewModel.searchMode = .fullText
                            searchViewModel.performSearch()
                        }) {
                            Label("全文搜索", systemImage: "doc.text.magnifyingglass")
                                .foregroundColor(searchViewModel.searchMode == .fullText ? .blue : .primary)
                        }
                        
                        Button(action: {
                            searchViewModel.searchMode = .tag
                            searchViewModel.performSearch()
                        }) {
                            Label("标签搜索", systemImage: "tag")
                                .foregroundColor(searchViewModel.searchMode == .tag ? .blue : .primary)
                        }
                    } label: {
                        HStack {
                            Text(searchViewModel.searchMode.rawValue)
                                .font(.caption)
                            SwiftUI.Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        SwiftUI.Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("搜索")
        }
    }
}

// 扩展View以隐藏键盘
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    let viewContext = PersistenceController.preview.container.viewContext
    let searchViewModel = SearchViewModel(viewContext: viewContext)
    let noteViewModel = NoteViewModel(viewContext: viewContext)
    let folderViewModel = FolderViewModel(viewContext: viewContext)
    
    return SearchView(
        searchViewModel: searchViewModel,
        noteViewModel: noteViewModel,
        folderViewModel: folderViewModel
    )
} 