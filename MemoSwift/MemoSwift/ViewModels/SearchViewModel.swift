//
//  SearchViewModel.swift
//  MemoSwift
//
//  Created by T-Mux on 5/4/25.
//

import Foundation
import CoreData
import SwiftUI
import Combine

class SearchViewModel: ObservableObject {
    private var viewContext: NSManagedObjectContext
    
    // 搜索结果
    @Published var searchResults: [Note] = []
    // 搜索查询
    @Published var searchQuery: String = ""
    // 搜索模式
    @Published var searchMode: SearchMode = .fullText
    // 搜索状态
    @Published var isSearching: Bool = false
    // 是否有更多搜索结果
    @Published var hasMoreResults: Bool = false
    // 搜索建议
    @Published var searchSuggestions: [String] = []
    
    // 搜索模式
    enum SearchMode: String, CaseIterable, Identifiable {
        case fullText = "全文搜索"
        case tag = "标签搜索"
        
        var id: String { self.rawValue }
        
        var description: String {
            switch self {
            case .fullText:
                return "在笔记标题和内容中搜索"
            case .tag:
                return "搜索包含特定标签的笔记"
            }
        }
        
        var iconName: String {
            switch self {
            case .fullText:
                return "doc.text.magnifyingglass"
            case .tag:
                return "tag"
            }
        }
    }
    
    private var searchTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.3
    private var lastSearchTime: Date = Date.distantPast
    private var maxResults: Int = 50
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    // 执行搜索操作
    func performSearch() {
        // 如果搜索查询为空，则清空结果
        guard !searchQuery.isEmpty else {
            searchResults = []
            isSearching = false
            hasMoreResults = false
            searchSuggestions = []
            return
        }
        
        // 生成搜索建议
        generateSearchSuggestions()
        
        // 取消之前的搜索任务
        searchTask?.cancel()
        
        // 如果距离上次搜索时间不到防抖间隔，则不执行搜索
        let now = Date()
        if now.timeIntervalSince(lastSearchTime) < debounceInterval {
            // 创建延迟任务
            searchTask = Task {
                // 等待防抖间隔
                try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        executeSearch()
                    }
                }
            }
        } else {
            // 立即执行搜索
            executeSearch()
        }
    }
    
    // 加载更多结果
    func loadMoreResults() {
        maxResults += 50
        executeSearch()
    }
    
    // 执行实际的搜索逻辑
    private func executeSearch() {
        isSearching = true
        lastSearchTime = Date()
        
        switch searchMode {
        case .fullText:
            searchByTextContent()
        case .tag:
            searchByTag()
        }
        
        isSearching = false
    }
    
    // 按文本内容搜索（标题和全文）
    private func searchByTextContent() {
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        
        // 全文搜索：搜索标题和内容
        fetchRequest.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@", 
            searchQuery, searchQuery
        )
        
        // 按更新时间降序排列
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        
        // 限制结果数量
        fetchRequest.fetchLimit = maxResults + 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            // 检查是否有更多结果
            if results.count > maxResults {
                searchResults = Array(results[0..<maxResults])
                hasMoreResults = true
            } else {
                searchResults = results
                hasMoreResults = false
            }
        } catch {
            print("搜索笔记时出错: \(error)")
            searchResults = []
            hasMoreResults = false
        }
    }
    
    // 按标签搜索
    private func searchByTag() {
        // 首先查找匹配的标签
        let tagFetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        tagFetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchQuery)
        
        do {
            let matchingTags = try viewContext.fetch(tagFetchRequest)
            
            if matchingTags.isEmpty {
                // 如果没有匹配的标签，则清空结果
                searchResults = []
                hasMoreResults = false
                return
            }
            
            // 收集所有匹配标签关联的笔记
            var allTaggedNotes: [Note] = []
            for tag in matchingTags {
                allTaggedNotes.append(contentsOf: tag.notesArray)
            }
            
            // 去重
            let uniqueNotes = Array(Set(allTaggedNotes))
            
            // 按更新时间排序
            let sortedNotes = uniqueNotes.sorted {
                ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast)
            }
            
            // 管理结果集大小
            if sortedNotes.count > maxResults {
                searchResults = Array(sortedNotes[0..<maxResults])
                hasMoreResults = true
            } else {
                searchResults = sortedNotes
                hasMoreResults = false
            }
        } catch {
            print("搜索标签时出错: \(error)")
            searchResults = []
            hasMoreResults = false
        }
    }
    
    // 重置搜索
    func resetSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
        hasMoreResults = false
        maxResults = 50
        searchSuggestions = []
    }
    
    // 生成搜索建议
    private func generateSearchSuggestions() {
        guard searchQuery.count >= 2 else {
            searchSuggestions = []
            return
        }
        
        // 获取最近的笔记标题和标签作为建议
        var suggestions: [String] = []
        
        // 查找匹配的标题
        let titleFetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        titleFetchRequest.predicate = NSPredicate(format: "title CONTAINS[cd] %@", searchQuery)
        titleFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)]
        titleFetchRequest.fetchLimit = 5
        
        // 查找匹配的标签
        let tagFetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        tagFetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchQuery)
        tagFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        tagFetchRequest.fetchLimit = 3
        
        // 执行查询
        do {
            let matchingNotes = try viewContext.fetch(titleFetchRequest)
            for note in matchingNotes {
                if !note.wrappedTitle.isEmpty && !suggestions.contains(note.wrappedTitle) {
                    suggestions.append(note.wrappedTitle)
                }
            }
            
            let matchingTags = try viewContext.fetch(tagFetchRequest)
            for tag in matchingTags {
                if !tag.wrappedName.isEmpty && !suggestions.contains(tag.wrappedName) {
                    suggestions.append("#" + tag.wrappedName)
                }
            }
            
            searchSuggestions = suggestions
        } catch {
            print("生成搜索建议时出错: \(error)")
            searchSuggestions = []
        }
    }
} 