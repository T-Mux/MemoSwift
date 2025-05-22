//
//  ReminderSettingView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import SwiftUI
import CoreData

struct ReminderSettingView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var reminderViewModel: ReminderViewModel
    let note: Note
    
    // 如果是编辑现有提醒，则传入reminder参数
    var existingReminder: Reminder?
    
    // 表单状态
    @State private var title: String
    @State private var reminderDate: Date
    @State private var isActive: Bool
    @State private var selectedRepeatType: Reminder.RepeatType
    @State private var showDeleteAlert = false
    @State private var isLoading = true // 添加加载状态
    
    // 初始化
    init(reminderViewModel: ReminderViewModel, note: Note, existingReminder: Reminder? = nil) {
        self.reminderViewModel = reminderViewModel
        self.note = note
        
        // 如果编辑现有提醒，则先获取最新的提醒对象
        if let reminder = existingReminder, let reminderId = reminder.id {
            // 先尝试刷新提醒
            reminderViewModel.viewContext.refresh(reminder, mergeChanges: true)
            
            // 使用ID重新获取提醒对象，确保获取最新状态
            let fetchRequest: NSFetchRequest<Reminder> = Reminder.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", reminderId as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try reminderViewModel.viewContext.fetch(fetchRequest)
                if let freshReminder = results.first {
                    self.existingReminder = freshReminder
                    
                    // 使用最新的提醒对象初始化状态
                    _title = State(initialValue: freshReminder.title)
                    _reminderDate = State(initialValue: freshReminder.reminderDate ?? Date())
                    _isActive = State(initialValue: freshReminder.isActive)
                    _selectedRepeatType = State(initialValue: freshReminder.wrappedRepeatType)
                    _isLoading = State(initialValue: false) // 数据已加载
                    return
                }
            } catch {
                print("获取提醒时出错: \(error.localizedDescription)")
            }
            
            // 如果获取失败，使用传入的reminder
            self.existingReminder = reminder
            _title = State(initialValue: reminder.title)
            _reminderDate = State(initialValue: reminder.reminderDate ?? Date())
            _isActive = State(initialValue: reminder.isActive)
            _selectedRepeatType = State(initialValue: reminder.wrappedRepeatType)
            _isLoading = State(initialValue: false)
        } else {
            // 新建提醒的默认值
            self.existingReminder = nil
            _title = State(initialValue: "提醒")
            _reminderDate = State(initialValue: Date().addingTimeInterval(3600)) // 默认1小时后
            _isActive = State(initialValue: true)
            _selectedRepeatType = State(initialValue: .none)
            _isLoading = State(initialValue: false) // 创建新提醒不需要加载
        }
    }
    
    var body: some View {
        NavigationView {
            // 将条件分支分成两个视图来简化表达式
            mainContentView
                .navigationTitle(existingReminder == nil ? "添加提醒" : "编辑提醒")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            saveReminder()
                        }
                        .fontWeight(.semibold)
                        .disabled(title.isEmpty || isLoading)
                    }
                }
                .alert(isPresented: $showDeleteAlert) {
                    Alert(
                        title: Text("删除提醒"),
                        message: Text("确定要删除这个提醒吗？此操作无法撤销。"),
                        primaryButton: .destructive(Text("删除")) {
                            deleteReminder()
                        },
                        secondaryButton: .cancel(Text("取消"))
                    )
                }
        }
    }
    
    // 将主内容分解为一个计算属性，简化body
    private var mainContentView: some View {
        Group {
            if isLoading {
                loadingView
            } else {
                formContentView
            }
        }
    }
    
    // 加载中视图
    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding()
            Text("加载提醒数据...")
                .font(.headline)
        }
        .onAppear {
            // 延迟一小段时间后检查数据
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let reminder = existingReminder {
                    // 再次刷新数据
                    reminderViewModel.viewContext.refresh(reminder, mergeChanges: true)
                    
                    // 更新状态
                    title = reminder.title
                    reminderDate = reminder.reminderDate ?? Date()
                    isActive = reminder.isActive
                    selectedRepeatType = reminder.wrappedRepeatType
                }
                
                // 关闭加载状态
                isLoading = false
            }
        }
    }
    
    // 表单内容视图
    private var formContentView: some View {
        Form {
            // 基本信息部分
            Section(header: Text("基本信息").font(.subheadline).foregroundColor(.primary)) {
                TextField("提醒标题", text: $title)
                    .font(.body)
                
                DatePicker("提醒时间", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .tint(.blue)
                
                Toggle("启用提醒", isOn: $isActive)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            
            // 重复设置部分
            Section(header: Text("重复设置").font(.subheadline).foregroundColor(.primary)) {
                Picker("重复", selection: $selectedRepeatType) {
                    ForEach(Reminder.RepeatType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // 删除按钮部分（仅在编辑模式显示）
            if existingReminder != nil {
                Section {
                    Button(action: { showDeleteAlert = true }) {
                        HStack {
                            SwiftUI.Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("删除提醒")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // 提醒预览部分
            Section(header: Text("预览").font(.subheadline).foregroundColor(.primary)) {
                reminderPreviewContent
            }
        }
    }
    
    // 提醒预览内容
    private var reminderPreviewContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 提醒标题预览
            HStack {
                SwiftUI.Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
                Text(title.isEmpty ? "提醒" : title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // 提醒时间预览
            HStack {
                SwiftUI.Image(systemName: "clock")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                Text(reminderDate, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(reminderDate, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 重复类型预览
            if selectedRepeatType != .none {
                HStack {
                    SwiftUI.Image(systemName: "repeat")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    Text(selectedRepeatType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            
            // 启用状态预览
            if !isActive {
                HStack {
                    SwiftUI.Image(systemName: "bell.slash")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    Text("已关闭")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // 保存提醒
    private func saveReminder() {
        if let reminder = existingReminder {
            // 更新现有提醒
            reminderViewModel.updateReminder(
                reminder: reminder,
                title: title,
                date: reminderDate,
                isActive: isActive,
                repeatType: selectedRepeatType
            )
        } else {
            // 创建新提醒
            reminderViewModel.createReminder(
                for: note,
                title: title,
                date: reminderDate,
                repeatType: selectedRepeatType
            )
        }
        
        // 关闭视图
        presentationMode.wrappedValue.dismiss()
    }
    
    // 删除提醒
    private func deleteReminder() {
        if let reminder = existingReminder {
            reminderViewModel.deleteReminder(reminder: reminder)
        }
        presentationMode.wrappedValue.dismiss()
    }
} 