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
    @Published var searchMode: SearchMode = .quick
    // 搜索状态
    @Published var isSearching: Bool = false
    // 是否有更多搜索结果
    @Published var hasMoreResults: Bool = false
    
    // 搜索模式
    enum SearchMode: String, CaseIterable, Identifiable {
        case quick = "快速搜索"
        case fullText = "全文搜索"
        
        var id: String { self.rawValue }
        
        var description: String {
            switch self {
            case .quick:
                return "在笔记标题中搜索"
            case .fullText:
                return "在笔记标题和内容中搜索"
            }
        }
        
        var iconName: String {
            switch self {
            case .quick:
                return "magnifyingglass"
            case .fullText:
                return "doc.text.magnifyingglass"
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
            return
        }
        
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
        
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        
        // 根据搜索模式设置谓词
        switch searchMode {
        case .quick:
            // 快速搜索：仅搜索标题
            fetchRequest.predicate = NSPredicate(
                format: "title CONTAINS[cd] %@", 
                searchQuery
            )
        case .fullText:
            // 全文搜索：搜索标题和内容
            fetchRequest.predicate = NSPredicate(
                format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@", 
                searchQuery, searchQuery
            )
        }
        
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
        
        isSearching = false
    }
    
    // 重置搜索
    func resetSearch() {
        searchQuery = ""
        searchResults = []
        isSearching = false
        hasMoreResults = false
        maxResults = 50
    }
} 