//
//  SearchResultsView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/4/25.
//

import SwiftUI

struct SearchResultsView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    @ObservedObject var noteViewModel: NoteViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索结果或空状态
            ZStack {
                if searchViewModel.isSearching {
                    // 加载中状态
                    VStack {
                        ProgressView()
                            .padding()
                        Text("正在搜索...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if searchViewModel.searchResults.isEmpty && !searchViewModel.searchQuery.isEmpty {
                    // 无结果状态
                    VStack(spacing: 16) {
                        SwiftUI.Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("未找到结果")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        if searchViewModel.searchMode == .quick {
                            Button(action: {
                                searchViewModel.searchMode = .fullText
                                searchViewModel.performSearch()
                            }) {
                                Text("尝试全文搜索")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if searchViewModel.searchQuery.isEmpty {
                    // 初始状态
                    VStack(spacing: 16) {
                        SwiftUI.Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("输入关键词开始搜索")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("可搜索笔记标题或内容")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    // 显示搜索结果
                    List {
                        ForEach(searchViewModel.searchResults) { note in
                            Button(action: {
                                noteViewModel.selectedNote = note
                            }) {
                                SearchResultRow(note: note, keyword: searchViewModel.searchQuery)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // 加载更多按钮
                        if searchViewModel.hasMoreResults {
                            Button(action: {
                                searchViewModel.loadMoreResults()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("加载更多结果")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
    }
}

// 搜索结果行视图
struct SearchResultRow: View {
    let note: Note
    let keyword: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题行
            HStack(alignment: .center, spacing: 12) {
                // 笔记图标
                SwiftUI.Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    // 标题
                    Text(highlightedTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    // 文件夹位置
                    HStack(spacing: 4) {
                        SwiftUI.Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text(note.folder?.fullPath ?? "未分类")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 日期
                Text(note.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // 内容预览
            if !note.wrappedContent.isEmpty {
                Text(highlightedPreview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 32)
            }
        }
        .padding(.vertical, 8)
    }
    
    // 高亮标题中的关键词
    private var highlightedTitle: AttributedString {
        highlightText(text: note.wrappedTitle, keyword: keyword)
    }
    
    // 高亮内容预览中的关键词
    private var highlightedPreview: AttributedString {
        // 提取关键词上下文
        let previewText = extractPreviewWithKeyword(from: note.wrappedContent, keyword: keyword)
        return highlightText(text: previewText, keyword: keyword)
    }
    
    // 高亮文本中的关键词
    private func highlightText(text: String, keyword: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        if !keyword.isEmpty {
            let ranges = text.ranges(of: keyword, options: [.caseInsensitive, .diacriticInsensitive])
            
            for range in ranges {
                if let attributedRange = Range<AttributedString.Index>(
                    NSRange(range, in: text),
                    in: attributedString
                ) {
                    attributedString[attributedRange].foregroundColor = .blue
                    attributedString[attributedRange].backgroundColor = Color.blue.opacity(0.1)
                    attributedString[attributedRange].font = .boldSystemFont(ofSize: UIFont.systemFontSize)
                }
            }
        }
        
        return attributedString
    }
    
    // 提取包含关键词的上下文预览
    private func extractPreviewWithKeyword(from text: String, keyword: String) -> String {
        guard !keyword.isEmpty, !text.isEmpty else {
            // 如果没有关键词或内容为空，返回内容的前200个字符
            let endIndex = text.index(text.startIndex, offsetBy: min(200, text.count))
            return String(text[..<endIndex])
        }
        
        // 查找第一个匹配位置
        if let range = text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            let previewLength = 150 // 预览总长度
            let keywordLength = keyword.count
            
            // 计算预览的起始位置（关键词前的上下文）
            let contextBefore = min(previewLength / 2, text.distance(from: text.startIndex, to: range.lowerBound))
            let startIndex = text.index(range.lowerBound, offsetBy: -contextBefore)
            
            // 计算预览的结束位置（关键词后的上下文）
            let remainingLength = previewLength - keywordLength - contextBefore
            let availableAfter = text.distance(from: range.upperBound, to: text.endIndex)
            let contextAfter = min(remainingLength, availableAfter)
            let endIndex = text.index(range.upperBound, offsetBy: contextAfter)
            
            // 提取预览文本
            var preview = String(text[startIndex..<endIndex])
            
            // 添加省略号
            if startIndex > text.startIndex {
                preview = "..." + preview
            }
            if endIndex < text.endIndex {
                preview = preview + "..."
            }
            
            return preview
        } else {
            // 如果关键词不在内容中，返回内容的前200个字符
            let endIndex = text.index(text.startIndex, offsetBy: min(200, text.count))
            return String(text[..<endIndex])
        }
    }
}

// 扩展String以查找所有匹配位置
extension String {
    func ranges(of searchString: String, options: NSString.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchRange = self.startIndex..<self.endIndex
        
        while let range = self.range(of: searchString, options: options, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<self.endIndex
        }
        
        return ranges
    }
} 
