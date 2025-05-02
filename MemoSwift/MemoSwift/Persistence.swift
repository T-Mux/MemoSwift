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
        
        // 创建示例文件夹
        let workFolder = Folder(context: viewContext)
        workFolder.id = UUID()
        workFolder.name = "工作"
        workFolder.createdAt = Date()
        
        let personalFolder = Folder(context: viewContext)
        personalFolder.id = UUID()
        personalFolder.name = "个人"
        personalFolder.createdAt = Date()
        
        // 创建示例笔记
        for i in 1...5 {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.title = "工作笔记 \(i)"
            newNote.content = "工作笔记 \(i) 的内容"
            newNote.createdAt = Date()
            newNote.updatedAt = Date()
            newNote.folder = workFolder
        }
        
        for i in 1...3 {
            let newNote = Note(context: viewContext)
            newNote.id = UUID()
            newNote.title = "个人笔记 \(i)"
            newNote.content = "个人笔记 \(i) 的内容"
            newNote.createdAt = Date()
            newNote.updatedAt = Date()
            newNote.folder = personalFolder
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
        
        // 创建管理对象模型，默认使用空模型
        var model = NSManagedObjectModel()
        
        // 手动创建并注册数据模型
        do {
            // 尝试创建内存中的临时模型
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
            
            folderEntity.properties = [folderIdAttribute, folderNameAttribute, folderCreatedAtAttribute]
            
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
            
            let noteCreatedAtAttribute = NSAttributeDescription()
            noteCreatedAtAttribute.name = "createdAt"
            noteCreatedAtAttribute.attributeType = .dateAttributeType
            noteCreatedAtAttribute.isOptional = true
            
            let noteUpdatedAtAttribute = NSAttributeDescription()
            noteUpdatedAtAttribute.name = "updatedAt"
            noteUpdatedAtAttribute.attributeType = .dateAttributeType
            noteUpdatedAtAttribute.isOptional = true
            
            // 创建关系
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
            
            // 设置反向关系
            notesToFolderRelationship.inverseRelationship = folderToNotesRelationship
            folderToNotesRelationship.inverseRelationship = notesToFolderRelationship
            
            noteEntity.properties = [noteIdAttribute, noteTitleAttribute, noteContentAttribute, 
                                     noteCreatedAtAttribute, noteUpdatedAtAttribute, notesToFolderRelationship]
            folderEntity.properties.append(folderToNotesRelationship)
            
            // 创建模型
            model = NSManagedObjectModel()
            model.entities = [folderEntity, noteEntity]
            
            print("已成功创建内存中的数据模型")
            
            // 验证模型是否有效
            if model.entities.isEmpty {
                throw NSError(domain: "com.yourdomain.MemoSwift", code: 100, userInfo: [NSLocalizedDescriptionKey: "创建的数据模型实体为空"])
            }
        } catch {
            print("创建内存中数据模型失败: \(error.localizedDescription)")
            // 使用空模型，已经在方法开始时设置为默认值
        }
        
        // 使用模型初始化容器
        container = NSPersistentCloudKitContainer(name: "MemoSwift", managedObjectModel: model)
        
        print("查找 Core Data 模型的可能位置:")
        let bundle = Bundle.main
        print("1. Bundle 路径: \(bundle.bundlePath)")
        if let resourcePath = bundle.resourcePath {
            print("2. 资源路径: \(resourcePath)")
        }
        
        // 配置 iCloud 同步
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.yourdomain.MemoSwift"
            )
            
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            
            // 添加更多日志记录
            print("持久化存储描述: \(description)")
            print("存储 URL: \(String(describing: description.url))")
        } else {
            print("警告: 无法获取持久化存储描述")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("加载持久化存储时出错: \(error), \(error.userInfo)")
                print("这可能是由于模型不匹配或模型位置不正确导致的。")
                
                // 发送通知以显示错误
                NotificationCenter.default.post(
                    name: NSNotification.Name("AppError"),
                    object: error
                )
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
}
