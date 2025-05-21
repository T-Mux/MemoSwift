import SwiftUI
import CoreData

struct TagSelectionListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var noteViewModel: NoteViewModel
    
    @State private var newTagName = ""
    @State private var showingAddTagAlert = false
    @State private var selectedTag: Tag?
    
    // 监听笔记更新
    @State private var updateTrigger = UUID()
    // 控制是否显示标签相关笔记列表
    @State private var showTagNotes = false
    // 添加一个标签列表状态
    @State private var tags: [Tag] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标签标题栏
            TagHeaderView(showingAddTagAlert: $showingAddTagAlert)
                .padding(.top, 4)
            
            // 标签列表
            TagHorizontalList(
                tags: tags,
                selectedTag: $selectedTag,
                showTagNotes: $showTagNotes
            )
            
            // 如果选中了标签并启用了显示，显示相关笔记
            if let selectedTag = selectedTag, showTagNotes {
                TagNotesPopupView(
                    tag: selectedTag,
                    noteViewModel: noteViewModel,
                    showTagNotes: $showTagNotes,
                    selectedTag: $selectedTag
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                ))
                .zIndex(1) // 确保弹出窗口在顶层
            }
        }
        .animation(.spring(response: 0.3), value: showTagNotes)
        .animation(.spring(response: 0.3), value: selectedTag?.id)
        .alert("添加新标签", isPresented: $showingAddTagAlert) {
            TextField("标签名称", text: $newTagName)
            
            Button("取消", role: .cancel) {
                newTagName = ""
            }
            
            Button("添加") {
                if !newTagName.isEmpty {
                    // 创建新标签
                    _ = noteViewModel.createTag(name: newTagName)
                    newTagName = ""
                    
                    // 更新标签列表
                    fetchTags()
                    
                    // 触发界面刷新
                    updateTrigger = UUID()
                }
            }
        }
        .onAppear {
            // 首次加载和每次出现时获取标签
            fetchTags()
        }
        .onChange(of: noteViewModel.noteUpdated) { _, _ in
            // 当笔记更新时，刷新标签列表和标签内容
            fetchTags()
            updateTrigger = UUID()
        }
        .onChange(of: updateTrigger) { _, _ in
            // 如果有选中的标签，刷新该标签数据
            if let tag = selectedTag {
                viewContext.refresh(tag, mergeChanges: true)
            }
            
            // 刷新标签列表
            fetchTags()
        }
    }
    
    // 获取所有标签
    private func fetchTags() {
        // 刷新标签列表
        DispatchQueue.main.async {
            self.tags = self.noteViewModel.fetchAllTags()
        }
    }
}

// 标签标题栏
struct TagHeaderView: View {
    @Binding var showingAddTagAlert: Bool
    
    var body: some View {
        HStack {
            Text("标签")
                .font(.headline)
                .padding(.leading)
            
            Spacer()
            
            Button {
                showingAddTagAlert = true
            } label: {
                SwiftUI.Image(systemName: "plus")
                    .imageScale(.medium)
            }
            .padding(.trailing)
        }
        .padding(.vertical, 4)
    }
}

// 水平标签列表
struct TagHorizontalList: View {
    // 使用传入的标签列表
    let tags: [Tag]
    @Binding var selectedTag: Tag?
    @Binding var showTagNotes: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(tags, id: \.id) { tag in
                    TagChip(tag: tag, isSelected: selectedTag?.id == tag.id) {
                        // 更简单的标签选择逻辑，避免使用animation
                        if selectedTag?.id == tag.id {
                            // 如果再次点击已选标签，则取消选择
                            selectedTag = nil
                            showTagNotes = false
                        } else {
                            // 选择新标签
                            selectedTag = tag
                            showTagNotes = true
                        }
                    }
                }
            }
            .padding(.horizontal)
            .animation(.spring(response: 0.3), value: tags.count)
        }
        .frame(height: 40)
        .padding(.bottom, 8)
    }
}

// 标签笔记弹出窗口
struct TagNotesPopupView: View {
    let tag: Tag
    @ObservedObject var noteViewModel: NoteViewModel
    @Binding var showTagNotes: Bool
    @Binding var selectedTag: Tag?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 弹窗标题
            HStack {
                Text("\(tag.wrappedName) 相关笔记")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
            }
            .padding(.top, 8)
            
            // 笔记列表或空状态
            if tag.notesArray.isEmpty {
                Text("没有相关笔记")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                NotesList(tag: tag, noteViewModel: noteViewModel, showTagNotes: $showTagNotes, selectedTag: $selectedTag)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// 笔记列表组件
struct NotesList: View {
    let tag: Tag
    @ObservedObject var noteViewModel: NoteViewModel
    @Binding var showTagNotes: Bool
    @Binding var selectedTag: Tag?
    
    var body: some View {
        List {
            ForEach(tag.notesArray, id: \.id) { note in
                NoteRowItem(note: note, noteViewModel: noteViewModel, showTagNotes: $showTagNotes, selectedTag: $selectedTag)
                    .contentShape(Rectangle()) // 确保整行都可点击
            }
        }
        .listStyle(PlainListStyle())
        .frame(height: 220)
        .cornerRadius(8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// 单个笔记行项目
struct NoteRowItem: View {
    let note: Note
    @ObservedObject var noteViewModel: NoteViewModel
    @Binding var showTagNotes: Bool
    @Binding var selectedTag: Tag?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            // 先清除标签和显示状态，关闭标签笔记视图
            showTagNotes = false
            selectedTag = nil
            
            // 使用异步处理，延迟处理笔记选择
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let id = note.id, let folder = note.folder {
                    // 首先设置选中的文件夹，确保导航到正确的文件夹
                    noteViewModel.folderViewModel?.selectedFolder = folder
                    
                    // 通过ID找到笔记，而不是直接使用传入的对象
                    let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    do {
                        let notes = try noteViewModel.viewContext.fetch(fetchRequest)
                        if let foundNote = notes.first {
                            // 先标记此笔记将被高亮显示
                            noteViewModel.highlightedNoteID = id
                            
                            // 使用UI主线程更新selectedNote
                            DispatchQueue.main.async {
                                // 短暂延迟后清除高亮状态
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    noteViewModel.highlightedNoteID = nil
                                }
                                
                                // 设置选中的笔记
                                noteViewModel.selectedNote = foundNote
                            }
                        }
                    } catch {
                        print("Error fetching note: \(error)")
                    }
                }
            }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // 标题行
                Text(note.wrappedTitle.isEmpty ? "无标题" : note.wrappedTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // 内容和文件夹信息
                HStack(alignment: .center) {
                    // 内容预览
                    Text(note.wrappedContent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 显示所属文件夹
                    if let folder = note.folder {
                        Text(folder.name)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(4)
                    }
                }
                
                // 日期信息
                Text(note.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 标签样式组件
struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(tag.wrappedName)
                    .font(.system(size: 14))
                    .lineLimit(1)
                
                Text("\(tag.notesArray.count)")
                    .font(.system(size: 12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// 显示标签关联的笔记列表
struct TagNotesListView: View {
    let tag: Tag
    @ObservedObject var noteViewModel: NoteViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(tag.wrappedName) 相关笔记")
                .font(.headline)
                .padding(.leading)
                .padding(.top, 8)
            
            List {
                ForEach(tag.notesArray, id: \.id) { note in
                    Button(action: {
                        // 点击笔记时设置为当前选中笔记
                        // 使用setSelectedNote方法确保正确更新UI
                        noteViewModel.setSelectedNote(note)
                    }) {
                        VStack(alignment: .leading) {
                            Text(note.wrappedTitle)
                                .font(.headline)
                                .lineLimit(1)
                            
                            HStack {
                                Text(note.wrappedContent)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                
                                Spacer()
                                
                                // 显示所属文件夹
                                if let folder = note.folder {
                                    Text(folder.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text(note.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(PlainListStyle())
        }
    }
} 
