//
//  MemoSwiftApp.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import SwiftUI
import CoreData
import BackgroundTasks
import CloudKit
import UserNotifications

@main
struct MemoSwiftApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showError = false
    @State private var errorMessage = ""
    @StateObject private var reminderViewModel: ReminderViewModel
    
    // 定义Info.plist内容，这将与自动生成的Info.plist合并
    @available(iOS 14.0, macOS 11.0, *)
    static var infoPlist: [String: Any] = [
        "UIBackgroundModes": ["remote-notification", "processing"],
        "NSCameraUsageDescription": "需要使用相机来拍摄图片进行OCR文字识别",
        "NSPhotoLibraryUsageDescription": "需要访问照片库选择图片进行OCR文字识别",
        "BGTaskSchedulerPermittedIdentifiers": [
            "com.yourdomain.MemoSwift.icloudSync",
            "com.yourdomain.MemoSwift.reminderCheck"
        ]
    ]
    
    init() {
        // 初始化提醒视图模型
        let reminderVM = ReminderViewModel(viewContext: PersistenceController.shared.container.viewContext)
        _reminderViewModel = StateObject(wrappedValue: reminderVM)
        
        // 设置全局错误处理
        setupGlobalErrorHandling()
        
        // 注册后台任务
        registerBackgroundTasks()
        
        // 检查iCloud账户状态
        checkCloudKitAvailability()
        
        // 设置通知代理
        setupNotificationDelegate()
        
        // 在App初始化时全局设置Alert按钮的颜色
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .systemBlue
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(reminderViewModel)
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppError"))) { notification in
                        if let error = notification.object as? Error {
                            showError = true
                            errorMessage = error.localizedDescription
                        }
                    }
                
                if showError {
                    ErrorOverlayView(message: errorMessage, dismiss: { showError = false })
                        .zIndex(1)
                }
            }
            .onAppear {
                // 应用启动时加载并安排提醒
                reminderViewModel.loadAndScheduleAllActiveReminders()
            }
        }
    }
    
    // 设置通知代理
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    // 设置全局错误处理
    private func setupGlobalErrorHandling() {
        // 设置NSSetUncaughtExceptionHandler捕获未处理的异常
        NSSetUncaughtExceptionHandler { exception in
            print("捕获到未处理的异常: \(exception.name), \(exception.reason ?? "")")
            // 记录异常信息到日志
            let userInfo = [
                NSLocalizedDescriptionKey: "应用发生异常: \(exception.name)",
                NSLocalizedFailureReasonErrorKey: exception.reason ?? "未知原因"
            ]
            let error = NSError(domain: "com.yourdomain.MemoSwift", code: 0, userInfo: userInfo)
            
            // 发送通知以显示错误
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("AppError"), object: error)
            }
        }
    }
    
    private func registerBackgroundTasks() {
        // 注册 iCloud 同步的后台任务
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourdomain.MemoSwift.icloudSync", using: nil) { task in
            self.handleCloudKitSync(task: task as! BGProcessingTask)
        }
        
        // 注册提醒检查的后台任务
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.yourdomain.MemoSwift.reminderCheck", using: nil) { task in
            self.handleReminderCheck(task: task as! BGProcessingTask)
        }
    }
    
    private func handleCloudKitSync(task: BGProcessingTask) {
        // 安排下一次后台任务
        scheduleBackgroundSync()
        
        // 执行 CloudKit 同步任务
        let syncOperation = {
            // 在此处理同步操作
            task.setTaskCompleted(success: true)
        }
        
        // 设置过期处理程序
        task.expirationHandler = {
            // 如需要，清理任务
        }
        
        // 开始同步操作
        syncOperation()
    }
    
    // 处理提醒检查后台任务
    private func handleReminderCheck(task: BGProcessingTask) {
        // 安排下一次后台任务
        scheduleReminderCheck()
        
        // 执行提醒检查
        let checkOperation = {
            // 重新加载和安排所有活动提醒
            self.reminderViewModel.loadAndScheduleAllActiveReminders()
            task.setTaskCompleted(success: true)
        }
        
        // 设置过期处理程序
        task.expirationHandler = {
            // 如需要，清理任务
        }
        
        // 开始检查操作
        checkOperation()
    }
    
    private func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: "com.yourdomain.MemoSwift.icloudSync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15分钟
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("安排后台同步任务失败: \(error)")
        }
    }
    
    // 安排提醒检查后台任务
    private func scheduleReminderCheck() {
        let request = BGProcessingTaskRequest(identifier: "com.yourdomain.MemoSwift.reminderCheck")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1小时
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("安排后台提醒检查任务失败: \(error)")
        }
    }
    
    private func checkCloudKitAvailability() {
        CKContainer.default().accountStatus { (accountStatus, error) in
            switch accountStatus {
            case .available:
                print("iCloud账户可用")
            case .noAccount:
                print("无iCloud账户")
            case .restricted:
                print("iCloud账户受限")
            case .couldNotDetermine:
                print("无法确定iCloud账户状态")
            case .temporarilyUnavailable:
                print("iCloud账户暂时不可用")
            @unknown default:
                print("未知的iCloud账户状态")
            }
            
            if let error = error {
                print("检查iCloud账户状态时出错: \(error.localizedDescription)")
            }
        }
    }
    
    // 重置Core Data数据库
    private func resetCoreDataDatabase() {
        guard let storeDescription = persistenceController.container.persistentStoreDescriptions.first,
              let storeURL = storeDescription.url else {
            print("无法获取Core Data存储URL")
            return
        }
        
        // 删除现有数据库文件
        let fileManager = FileManager.default
        let sqliteFiles = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal")
        ]
        
        for url in sqliteFiles {
            do {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                    print("已删除Core Data文件: \(url.path)")
                }
            } catch {
                print("删除Core Data文件失败: \(url.path), 错误: \(error)")
            }
        }
        
        // 重新加载持久化存储
        persistenceController.container.loadPersistentStores { (storeDescription, error) in
            if let error = error {
                print("重新加载Core Data存储失败: \(error.localizedDescription)")
            } else {
                print("成功重新创建Core Data数据库")
            }
        }
    }
}

struct ErrorOverlayView: View {
    let message: String
    let dismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                SwiftUI.Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("错误")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
                
                Button("确定") {
                    dismiss()
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
            .background(Color.gray.opacity(0.8))
            .cornerRadius(15)
            .padding(30)
        }
    }
}

// 添加通知代理类
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // 当应用在前台时收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 允许通知在前台显示
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    // 用户点击通知时的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // 提取笔记ID和提醒ID
        if let noteIdString = userInfo["noteId"] as? String,
           let noteId = UUID(uuidString: noteIdString) {
            // 发送通知以打开特定笔记
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenNoteFromNotification"),
                object: nil,
                userInfo: ["noteId": noteId]
            )
            
            // 如果是重复提醒，需要设置下一次提醒
            if let reminderIdString = userInfo["reminderId"] as? String,
               let reminderId = UUID(uuidString: reminderIdString) {
                // 发送通知以处理提醒
                NotificationCenter.default.post(
                    name: NSNotification.Name("HandleReminderTriggered"),
                    object: nil,
                    userInfo: ["reminderId": reminderId]
                )
            }
        }
        
        completionHandler()
    }
}
