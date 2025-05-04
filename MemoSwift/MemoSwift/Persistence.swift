//
//  Persistence.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import CoreData
import Foundation

class PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建根文件夹
        let workFolder = Folder(context: viewContext)
        workFolder.id = UUID()
        workFolder.name = "工作"
        workFolder.createdAt = Date()
        
        let personalFolder = Folder(context: viewContext)
        personalFolder.id = UUID()
        personalFolder.name = "个人"
        personalFolder.createdAt = Date()
        
        // 创建子文件夹
        let projectsFolder = Folder(context: viewContext)
        projectsFolder.id = UUID()
        projectsFolder.name = "项目"
        projectsFolder.createdAt = Date()
        projectsFolder.parentFolder = workFolder
        
        let meetingsFolder = Folder(context: viewContext)
        meetingsFolder.id = UUID()
        meetingsFolder.name = "会议"
        meetingsFolder.createdAt = Date()
        meetingsFolder.parentFolder = workFolder
        
        let travelFolder = Folder(context: viewContext)
        travelFolder.id = UUID()
        travelFolder.name = "旅行"
        travelFolder.createdAt = Date()
        travelFolder.parentFolder = personalFolder
        
        // 创建示例笔记 - 工作文件夹
        for i in 1...3 {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.title = "工作笔记 \(i)"
            newNote.content = "工作笔记 \(i) 的内容"
            newNote.createdAt = Date()
            newNote.updatedAt = Date()
            newNote.folder = workFolder
        }
        
        // 项目子文件夹的笔记
        for i in 1...2 {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.title = "项目笔记 \(i)"
            newNote.content = "项目笔记 \(i) 的详细内容"
            newNote.createdAt = Date()
            newNote.updatedAt = Date()
            newNote.folder = projectsFolder
        }
        
        // 会议子文件夹的笔记
        for i in 1...2 {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.title = "会议记录 \(i)"
            newNote.content = "会议记录 \(i) 的详细内容"
            newNote.createdAt = Date()
            newNote.updatedAt = Date()
            newNote.folder = meetingsFolder
        }
        
        // 个人文件夹的笔记
        for i in 1...2 {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.title = "个人笔记 \(i)"
            newNote.content = "个人笔记 \(i) 的内容"
            newNote.createdAt = Date()
            newNote.updatedAt = Date()
            newNote.folder = personalFolder
        }
        
        // 旅行子文件夹的笔记
        for i in 1...2 {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.title = "旅行计划 \(i)"
            newNote.content = "旅行计划 \(i) 的详细内容"
            newNote.createdAt = Date()
            newNote.updatedAt = Date()
            newNote.folder = travelFolder
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("保存上下文时出错: \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        print("初始化 Core Data 容器")
        
        // 使用项目中定义的Core Data模型
        // 尝试明确指定模型URL
        let modelURL = Bundle.main.url(forResource: "MemoSwift", withExtension: "momd")
        
        if let url = modelURL {
            print("找到Core Data模型文件: \(url.path)")
            let model = NSManagedObjectModel(contentsOf: url)
            if let managedObjectModel = model {
                container = NSPersistentCloudKitContainer(name: "MemoSwift", managedObjectModel: managedObjectModel)
            } else {
                print("⚠️ 无法加载模型文件，尝试备用方案")
                container = NSPersistentCloudKitContainer(name: "MemoSwift")
            }
        } else {
            print("⚠️ 找不到Core Data模型文件，尝试加载CoreDataModel目录中的模型")
            
            // 尝试从CoreDataModel目录加载
            let alternateURL = Bundle.main.url(forResource: "MemoSwift", withExtension: "momd", subdirectory: "CoreDataModel")
            if let altURL = alternateURL, let model = NSManagedObjectModel(contentsOf: altURL) {
                print("从CoreDataModel目录加载模型成功")
                container = NSPersistentCloudKitContainer(name: "MemoSwift", managedObjectModel: model)
            } else {
                print("⚠️ 所有尝试都失败，使用动态创建的模型")
                // 动态创建模型作为最后的备用方案
                let dynamicModel = PersistenceController.createDynamicModel()
                container = NSPersistentCloudKitContainer(name: "MemoSwift", managedObjectModel: dynamicModel)
            }
        }
        
        print("查找 Core Data 模型的可能位置:")
        let bundle = Bundle.main
        print("1. Bundle 路径: \(bundle.bundlePath)")
        if let resourcePath = bundle.resourcePath {
            print("2. 资源路径: \(resourcePath)")
        }
        
        // 配置 iCloud 同步
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // 仅在非内存模式下启用CloudKit
            if !inMemory {
                let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.com.yourdomain.MemoSwift"
                )
                description.cloudKitContainerOptions = cloudKitOptions
            } else {
                // 内存模式下不使用CloudKit
                description.cloudKitContainerOptions = nil
            }
            
            // 如果是内存模式，使用内存中的存储
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            
            // 添加更多日志记录
            print("持久化存储描述: \(description)")
            print("存储 URL: \(String(describing: description.url))")
        } else {
            print("警告: 无法获取持久化存储描述")
        }
        
        if container.persistentStoreDescriptions.isEmpty {
            print("⚠️ 容器没有持久化存储描述，创建一个")
            let storeDescription = NSPersistentStoreDescription()
            let storeURL = URL.storeURL(for: "group.com.yourdomain.MemoSwift", databaseName: "MemoSwift")
            storeDescription.url = storeURL
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        print("持久化存储描述: \(String(describing: container.persistentStoreDescriptions.first))")
        print("存储 URL: \(String(describing: container.persistentStoreDescriptions.first?.url))")
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("加载持久化存储时出错: \(error), \(error.userInfo)")
                print("这可能是由于模型不匹配或模型位置不正确导致的。错误代码: \(error.code)")
                
                // 尝试处理一些常见错误
                if error.domain == NSCocoaErrorDomain && error.code == 134_400 {
                    // 处理CloudKit账户不可用错误 - 禁用CloudKit集成
                    print("检测到CloudKit账户不可用，禁用CloudKit集成")
                    if let description = self.container.persistentStoreDescriptions.first {
                        description.cloudKitContainerOptions = nil
                        
                        // 重新加载存储
                        self.container.loadPersistentStores { (newStoreDescription, newError) in
                            if let newError = newError {
                                print("尝试禁用CloudKit后仍然无法加载存储: \(newError)")
                                print("尝试禁用CloudKit后仍然无法加载存储: \(newError.localizedDescription)")
                                
                                // 最后尝试：创建纯本地存储，不使用任何高级功能
                                self.createLocalOnlyStore()
                            } else {
                                print("禁用CloudKit后成功加载持久化存储")
                            }
                        }
                        return
                    }
                } else if error.domain == NSCocoaErrorDomain && 
                          (error.code == NSPersistentStoreIncompatibleVersionHashError || 
                           error.code == NSMigrationError || 
                           error.code == NSMigrationMissingSourceModelError ||
                           error.code == 134060) { // CloudKit schema compatibility error
                    // 处理模型不兼容或迁移错误
                    print("检测到模型版本不兼容或CloudKit架构不兼容，尝试删除现有存储并重新创建")
                    // 禁用CloudKit然后重建存储
                    if let description = self.container.persistentStoreDescriptions.first {
                        description.cloudKitContainerOptions = nil
                        
                        // 删除现有存储文件
                        self.deleteStoreFiles()
                        
                        // 重新加载存储
                        self.container.loadPersistentStores { (newStoreDescription, newError) in
                            if let newError = newError {
                                print("重新创建存储后仍然失败: \(newError)")
                                
                                // 最后尝试：创建纯本地存储
                                self.createLocalOnlyStore()
                            } else {
                                print("成功重新创建并加载存储")
                            }
                        }
                        return
                    }
                }
                
                // 发送通知以显示错误
                print("🔴 持久化存储错误: \(error.localizedDescription)")
                
                // 最后尝试：总是确保我们有一个工作的存储
                self.createLocalOnlyStore()
            } else {
                print("成功加载持久化存储: \(storeDescription)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // 启用后台通知
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePersistentStoreRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange, object: container
        )
    }
    
    @objc
    private func handlePersistentStoreRemoteChange(_ notification: Notification) {
        // 处理远程更改
        Task {
            await container.viewContext.perform {
                self.container.viewContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    // 动态创建Core Data模型
    private static func createDynamicModel() -> NSManagedObjectModel {
        print("动态创建Core Data模型...")
        let model = NSManagedObjectModel()
        
        // 创建Folder实体
        let folderEntity = NSEntityDescription()
        folderEntity.name = "Folder"
        folderEntity.managedObjectClassName = "Folder"
        
        let folderIdAttribute = NSAttributeDescription()
        folderIdAttribute.name = "id"
        folderIdAttribute.attributeType = .UUIDAttributeType
        folderIdAttribute.isOptional = true
        
        let folderNameAttribute = NSAttributeDescription()
        folderNameAttribute.name = "name"
        folderNameAttribute.attributeType = .stringAttributeType
        folderNameAttribute.isOptional = false
        folderNameAttribute.defaultValue = "新文件夹"
        
        let folderCreatedAtAttribute = NSAttributeDescription()
        folderCreatedAtAttribute.name = "createdAt"
        folderCreatedAtAttribute.attributeType = .dateAttributeType
        folderCreatedAtAttribute.isOptional = true
        
        // 创建Note实体
        let noteEntity = NSEntityDescription()
        noteEntity.name = "Note"
        noteEntity.managedObjectClassName = "Note"
        
        let noteIdAttribute = NSAttributeDescription()
        noteIdAttribute.name = "id"
        noteIdAttribute.attributeType = .UUIDAttributeType
        noteIdAttribute.isOptional = true
        
        let noteTitleAttribute = NSAttributeDescription()
        noteTitleAttribute.name = "title"
        noteTitleAttribute.attributeType = .stringAttributeType
        noteTitleAttribute.isOptional = false
        noteTitleAttribute.defaultValue = "新笔记"
        
        let noteContentAttribute = NSAttributeDescription()
        noteContentAttribute.name = "content"
        noteContentAttribute.attributeType = .stringAttributeType
        noteContentAttribute.isOptional = true
        
        // 添加富文本内容属性
        let noteRichContentAttribute = NSAttributeDescription()
        noteRichContentAttribute.name = "richContent"
        noteRichContentAttribute.attributeType = .binaryDataAttributeType
        noteRichContentAttribute.isOptional = true
        
        let noteCreatedAtAttribute = NSAttributeDescription()
        noteCreatedAtAttribute.name = "createdAt"
        noteCreatedAtAttribute.attributeType = .dateAttributeType
        noteCreatedAtAttribute.isOptional = true
        
        let noteUpdatedAtAttribute = NSAttributeDescription()
        noteUpdatedAtAttribute.name = "updatedAt"
        noteUpdatedAtAttribute.attributeType = .dateAttributeType
        noteUpdatedAtAttribute.isOptional = true
        
        // 创建Image实体
        let imageEntity = NSEntityDescription()
        imageEntity.name = "Image"
        imageEntity.managedObjectClassName = "Image"
        
        let imageIdAttribute = NSAttributeDescription()
        imageIdAttribute.name = "id"
        imageIdAttribute.attributeType = .UUIDAttributeType
        imageIdAttribute.isOptional = true
        
        let imageDataAttribute = NSAttributeDescription()
        imageDataAttribute.name = "data"
        imageDataAttribute.attributeType = .binaryDataAttributeType
        imageDataAttribute.isOptional = true
        
        let imageCreatedAtAttribute = NSAttributeDescription()
        imageCreatedAtAttribute.name = "createdAt"
        imageCreatedAtAttribute.attributeType = .dateAttributeType
        imageCreatedAtAttribute.isOptional = true
        
        // 创建Note和Image之间的关系
        let noteToImagesRelationship = NSRelationshipDescription()
        noteToImagesRelationship.name = "images"
        noteToImagesRelationship.destinationEntity = imageEntity
        noteToImagesRelationship.isOptional = true
        noteToImagesRelationship.deleteRule = .cascadeDeleteRule
        
        let imageToNoteRelationship = NSRelationshipDescription()
        imageToNoteRelationship.name = "note"
        imageToNoteRelationship.destinationEntity = noteEntity
        imageToNoteRelationship.isOptional = true
        imageToNoteRelationship.deleteRule = .nullifyDeleteRule
        imageToNoteRelationship.maxCount = 1
        
        // 创建Note和Folder之间的关系
        let notesToFolderRelationship = NSRelationshipDescription()
        notesToFolderRelationship.name = "folder"
        notesToFolderRelationship.destinationEntity = folderEntity
        notesToFolderRelationship.isOptional = true
        notesToFolderRelationship.deleteRule = .nullifyDeleteRule
        notesToFolderRelationship.maxCount = 1
        
        let folderToNotesRelationship = NSRelationshipDescription()
        folderToNotesRelationship.name = "notes"
        folderToNotesRelationship.destinationEntity = noteEntity
        folderToNotesRelationship.isOptional = true
        folderToNotesRelationship.deleteRule = .cascadeDeleteRule
        
        // 创建文件夹的父子关系
        let childToParentRelationship = NSRelationshipDescription()
        childToParentRelationship.name = "parentFolder"
        childToParentRelationship.destinationEntity = folderEntity
        childToParentRelationship.isOptional = true
        childToParentRelationship.deleteRule = .nullifyDeleteRule
        childToParentRelationship.maxCount = 1
        
        let parentToChildrenRelationship = NSRelationshipDescription()
        parentToChildrenRelationship.name = "childFolders"
        parentToChildrenRelationship.destinationEntity = folderEntity
        parentToChildrenRelationship.isOptional = true
        parentToChildrenRelationship.deleteRule = .cascadeDeleteRule
        
        // 设置反向关系
        notesToFolderRelationship.inverseRelationship = folderToNotesRelationship
        folderToNotesRelationship.inverseRelationship = notesToFolderRelationship
        
        childToParentRelationship.inverseRelationship = parentToChildrenRelationship
        parentToChildrenRelationship.inverseRelationship = childToParentRelationship
        
        noteToImagesRelationship.inverseRelationship = imageToNoteRelationship
        imageToNoteRelationship.inverseRelationship = noteToImagesRelationship
        
        // 设置实体的属性
        noteEntity.properties = [
            noteIdAttribute, 
            noteTitleAttribute, 
            noteContentAttribute,
            noteRichContentAttribute,
            noteCreatedAtAttribute, 
            noteUpdatedAtAttribute, 
            notesToFolderRelationship,
            noteToImagesRelationship
        ]
        
        folderEntity.properties = [
            folderIdAttribute, 
            folderNameAttribute, 
            folderCreatedAtAttribute, 
            folderToNotesRelationship, 
            childToParentRelationship, 
            parentToChildrenRelationship
        ]
        
        imageEntity.properties = [
            imageIdAttribute,
            imageDataAttribute,
            imageCreatedAtAttribute,
            imageToNoteRelationship
        ]
        
        // 将实体添加到模型
        model.entities = [folderEntity, noteEntity, imageEntity]
        
        print("成功动态创建模型，实体数量: \(model.entities.count)")
        return model
    }
}

// URL扩展，用于获取SQLite存储URL
extension URL {
    static func storeURL(for appGroup: String, databaseName: String) -> URL {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            // 如果无法获取应用组容器，则使用文档目录
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            return urls[0].appendingPathComponent("\(databaseName).sqlite")
        }
        return fileContainer.appendingPathComponent("\(databaseName).sqlite")
    }
}

extension PersistenceController {
    // 删除存储文件
    private func deleteStoreFiles() {
        let storeURL = self.container.persistentStoreDescriptions.first?.url
        if let url = storeURL {
            let fileManager = FileManager.default
            let sqliteFiles = [
                url,
                url.appendingPathExtension("shm"),
                url.appendingPathExtension("wal")
            ]
            
            for fileURL in sqliteFiles {
                do {
                    if fileManager.fileExists(atPath: fileURL.path) {
                        try fileManager.removeItem(at: fileURL)
                        print("已删除文件: \(fileURL.path)")
                    }
                } catch {
                    print("删除文件失败: \(fileURL.path), 错误: \(error)")
                }
            }
        }
    }
    
    // 创建纯本地存储 - 没有CloudKit、没有历史跟踪等
    private func createLocalOnlyStore() {
        print("尝试创建纯本地存储...")
        
        // 删除旧的存储文件
        deleteStoreFiles()
        
        // 创建一个简单的本地存储描述
        let storeDescription = NSPersistentStoreDescription()
        if let storeURL = container.persistentStoreDescriptions.first?.url {
            storeDescription.url = storeURL
        } else {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            storeDescription.url = documentsDirectory.appendingPathComponent("LocalMemoSwift.sqlite")
        }
        
        // 禁用所有高级功能
        storeDescription.cloudKitContainerOptions = nil
        storeDescription.setOption(false as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(false as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.persistentStoreDescriptions = [storeDescription]
        
        // 加载存储
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error {
                print("纯本地存储创建失败: \(error.localizedDescription)")
                
                // 如果仍然失败，使用内存存储作为最后的备选
                self.useInMemoryStore()
            } else {
                print("成功创建并加载纯本地存储")
            }
        }
    }
    
    // 使用内存存储作为最后的备选方案
    private func useInMemoryStore() {
        print("使用内存存储...")
        
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.type = NSInMemoryStoreType
        
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error {
                print("内存存储创建也失败了: \(error.localizedDescription)")
                
                // 向用户显示严重错误
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AppError"),
                        object: NSError(
                            domain: "com.yourdomain.MemoSwift",
                            code: 1001,
                            userInfo: [NSLocalizedDescriptionKey: "无法创建数据存储，应用可能无法正常工作"]
                        )
                    )
                }
            } else {
                print("成功创建并加载内存存储 (临时数据)")
            }
        }
    }
    
    // 处理持久化存储错误
    func handlePersistentStoreError(_ error: NSError) {
        print("🔴 持久化存储错误: \(error.localizedDescription)")
        if error.code == NSManagedObjectValidationError {
            print("数据验证错误，可能是数据模型定义有问题")
        } else if error.code == NSPersistentStoreIncompatibleVersionHashError {
            print("存储版本不兼容，需要迁移")
        }
        
        // 发送错误通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("AppError"),
                object: error
            )
        }
    }
    
    // 重新创建持久化存储
    func recreatePersistentStore() {
        print("尝试重新创建持久化存储...")
        
        // 删除旧的存储文件
        deleteStoreFiles()
        
        // 重新加载存储
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("重新创建存储后仍然失败: \(error)")
                self.handlePersistentStoreError(error)
                
                // 尝试创建本地存储
                self.createLocalOnlyStore()
            } else {
                print("成功重新创建并加载存储")
            }
        }
    }
}
