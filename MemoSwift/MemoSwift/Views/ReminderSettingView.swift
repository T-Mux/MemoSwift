//
//  ReminderSettingView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import SwiftUI

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
    
    // 初始化
    init(reminderViewModel: ReminderViewModel, note: Note, existingReminder: Reminder? = nil) {
        self.reminderViewModel = reminderViewModel
        self.note = note
        self.existingReminder = existingReminder
        
        // 初始化状态
        if let reminder = existingReminder {
            _title = State(initialValue: reminder.title)
            _reminderDate = State(initialValue: reminder.reminderDate ?? Date())
            _isActive = State(initialValue: reminder.isActive)
            _selectedRepeatType = State(initialValue: reminder.wrappedRepeatType)
        } else {
            // 新建提醒的默认值
            _title = State(initialValue: "提醒")
            _reminderDate = State(initialValue: Date().addingTimeInterval(3600)) // 默认1小时后
            _isActive = State(initialValue: true)
            _selectedRepeatType = State(initialValue: .none)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("提醒标题", text: $title)
                    
                    DatePicker("提醒时间", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    Toggle("启用提醒", isOn: $isActive)
                }
                
                Section(header: Text("重复设置")) {
                    Picker("重复", selection: $selectedRepeatType) {
                        ForEach(Reminder.RepeatType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if existingReminder != nil {
                    Section {
                                            Button(action: deleteReminder) {
                        HStack {
                            SwiftUI.Image(systemName: "trash")
                            Text("删除提醒")
                        }
                        .foregroundColor(.red)
                        }
                    }
                }
            }
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
                }
            }
        }
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