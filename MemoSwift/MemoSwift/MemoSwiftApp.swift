//
//  MemoSwiftApp.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import SwiftUI
import CoreData
import BackgroundTasks

@main
struct MemoSwiftApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showError = false
    @State private var errorMessage = ""
    
    init() {
        // 设置全局错误处理
        setupGlobalErrorHandling()
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
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
        }
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
    
    private func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: "com.yourdomain.MemoSwift.icloudSync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15分钟
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("安排后台任务失败: \(error)")
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
                Image(systemName: "exclamationmark.circle.fill")
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
