import SwiftUI
import CoreData

struct TagListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject private var noteViewModel: NoteViewModel
    @State private var newTagName = ""
    @State private var showingAddTagAlert = false
    
    // Create a separate initializer for the view model
    private let viewModelWrapper: NoteViewModelWrapper
    
    // Wrapper class to help with initialization
    private class NoteViewModelWrapper {
        let viewModel: NoteViewModel
        
        init(viewContext: NSManagedObjectContext) {
            self.viewModel = NoteViewModel(viewContext: viewContext)
        }
    }
    
    init(viewContext: NSManagedObjectContext) {
        // Create the wrapper first
        self.viewModelWrapper = NoteViewModelWrapper(viewContext: viewContext)
        
        // Initialize the observed object from the wrapper
        self.noteViewModel = viewModelWrapper.viewModel
    }
    
    // Action to show add tag alert
    private func showAddTagAlert() {
        showingAddTagAlert = true
    }
    
    // Action to add a new tag
    private func addNewTag() {
        if !newTagName.isEmpty {
            _ = noteViewModel.createTag(name: newTagName)
            newTagName = ""
            showingAddTagAlert = false
        }
    }
    
    // Action to cancel tag addition
    private func cancelAddTag() {
        newTagName = ""
        showingAddTagAlert = false
    }
    
    var body: some View {
        NavigationView {
            List {
                // 标签列表
                tagListSection
            }
            .navigationTitle("标签管理")
            .navigationBarItems(trailing: 
                Button(action: showAddTagAlert) {
                SwiftUI.Image(systemName: "plus")
                }
            )
            .alert("添加新标签", isPresented: $showingAddTagAlert) {
                TextField("标签名称", text: $newTagName)
                
                Button("取消", role: .cancel, action: cancelAddTag)
                
                Button("添加", action: addNewTag)
            }
        }
    }
    
    // Separate the tag list into its own computed property
    private var tagListSection: some View {
        // Fetch tags separately to help with type checking
        let tags = noteViewModel.fetchAllTags()
        
        return ForEach(tags, id: \.id) { tag in
            HStack {
                Text(tag.wrappedName)
                Spacer()
                Text("\(tag.notesArray.count) 笔记")
                    .foregroundColor(.secondary)
            }
            .contextMenu {
                Button(action: { 
                    // Directly call delete on the view model
                    noteViewModel.deleteTag(tag)
                }) {
                    Label("删除标签", systemImage: "trash")
                }
            }
        }
    }
}

struct TagListView_Previews: PreviewProvider {
    static var previews: some View {
        // 使用预览上下文
        let context = PersistenceController.preview.container.viewContext
        TagListView(viewContext: context)
    }
} 
