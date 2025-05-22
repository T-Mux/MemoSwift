//
//  ReminderListView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import SwiftUI
import CoreData

struct ReminderListView: View {
    @ObservedObject var reminderViewModel: ReminderViewModel
    let note: Note
    
    @State private var showAddReminderSheet = false
    @State private var selectedReminder: Reminder?
    @State private var showEditReminderSheet = false
    @State private var isPreparingReminder = false // 添加状态表示正在准备提醒数据
    @State private var preparedReminderId: UUID? // 保存已准备好的提醒ID
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("提醒")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                Button(action: {
                    showAddReminderSheet = true
                }) {
                    SwiftUI.Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                }
                .padding(.trailing)
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            
            if note.remindersArray.isEmpty {
                // 没有提醒时显示的视图
                VStack {
                    Spacer()
                    
                    SwiftUI.Image(systemName: "bell.slash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("没有提醒")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("点击 + 按钮添加提醒")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                    
                    Spacer()
                }
                .padding()
            } else {
                // 提醒列表
                List {
                    // 活动提醒
                    if !note.activeRemindersArray.isEmpty {
                        Section(header: Text("活动提醒")) {
                            ForEach(note.activeRemindersArray, id: \.wrappedId) { reminder in
                                ReminderRow(reminder: reminder)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        // 显示加载状态
                                        isPreparingReminder = true
                                        // 先保存ID然后准备提醒
                                        preparedReminderId = reminder.id
                                        prepareAndEditReminder(reminder)
                                    }
                            }
                        }
                    }
                    
                    // 不活动的提醒
                    let inactiveReminders = note.remindersArray.filter { !$0.isActive }
                    if !inactiveReminders.isEmpty {
                        Section(header: Text("已关闭提醒")) {
                            ForEach(inactiveReminders, id: \.wrappedId) { reminder in
                                ReminderRow(reminder: reminder)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        // 显示加载状态
                                        isPreparingReminder = true
                                        // 先保存ID然后准备提醒
                                        preparedReminderId = reminder.id
                                        prepareAndEditReminder(reminder)
                                    }
                            }
                        }
                    }
                }
            }
        }
        // 添加新提醒的表单
        .sheet(isPresented: $showAddReminderSheet) {
            ReminderSettingView(
                reminderViewModel: reminderViewModel,
                note: note
            )
        }
        // 编辑现有提醒的表单
        .sheet(isPresented: $showEditReminderSheet, onDismiss: {
            // 清空选中的提醒，避免在下一次打开时使用过期的引用
            selectedReminder = nil
            preparedReminderId = nil
            isPreparingReminder = false
        }) {
            if let reminderToEdit = selectedReminder {
                ReminderSettingView(
                    reminderViewModel: reminderViewModel,
                    note: note,
                    existingReminder: reminderToEdit
                )
            } else if isPreparingReminder {
                // 显示加载指示器
                VStack {
                    ProgressView()
                        .padding()
                    Text("加载提醒数据...")
                        .font(.headline)
                }
                .onAppear {
                    // 如果有保存的ID，尝试再次获取
                    if let savedId = preparedReminderId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            fetchReminderById(savedId)
                        }
                    } else {
                        // 如果没有ID，关闭sheet
                        showEditReminderSheet = false
                    }
                }
            }
        }
        // 在视图出现时刷新提醒
        .onAppear {
            // 刷新笔记中的提醒状态
            note.refreshReminders(context: reminderViewModel.viewContext)
        }
        // 监听提醒更新
        .onReceive(reminderViewModel.$reminderUpdated) { _ in
            // 刷新提醒列表
            note.refreshReminders(context: reminderViewModel.viewContext)
            
            // 如果当前正在编辑提醒，尝试刷新选中的提醒
            if showEditReminderSheet, let reminderId = preparedReminderId {
                fetchReminderById(reminderId)
            }
        }
    }
    
    // 准备并编辑提醒 - 确保获取最新的提醒对象
    private func prepareAndEditReminder(_ reminder: Reminder) {
        guard let reminderId = reminder.id else { 
            isPreparingReminder = false
            return 
        }
        
        // 先展示加载界面
        showEditReminderSheet = true
        
        // 然后异步获取提醒数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            fetchReminderById(reminderId)
        }
    }
    
    // 通过ID获取提醒
    private func fetchReminderById(_ reminderId: UUID) {
        // 使用ID重新获取提醒对象，确保获取最新状态
        let fetchRequest: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", reminderId as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try reminderViewModel.viewContext.fetch(fetchRequest)
            if let freshReminder = results.first {
                // 确保视图上下文中的对象是最新的
                reminderViewModel.viewContext.refresh(freshReminder, mergeChanges: true)
                
                // 更新选中的提醒并关闭加载状态
                DispatchQueue.main.async {
                    selectedReminder = freshReminder
                    isPreparingReminder = false
                }
            } else {
                print("错误：无法找到ID为 \(reminderId) 的提醒")
                DispatchQueue.main.async {
                    isPreparingReminder = false
                    showEditReminderSheet = false
                }
            }
        } catch {
            print("获取提醒时出错: \(error.localizedDescription)")
            DispatchQueue.main.async {
                isPreparingReminder = false
                showEditReminderSheet = false
            }
        }
    }
}

// 提醒行视图
struct ReminderRow: View {
    let reminder: Reminder
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.headline)
                    .foregroundColor(reminder.isActive ? .primary : .secondary)
                
                HStack(spacing: 4) {
                    // 提醒时间
                    Text(reminder.formattedReminderDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 提醒状态（过期/即将到期）
                    if reminder.isActive {
                        if reminder.isOverdue {
                            Text("已过期")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemRed).opacity(0.1))
                                )
                        } else {
                            Text(reminder.timeRemainingDescription)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemBlue).opacity(0.1))
                                )
                        }
                    }
                }
                
                // 显示重复类型
                if reminder.wrappedRepeatType != .none {
                    Text(reminder.wrappedRepeatType.displayName)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGreen).opacity(0.1))
                        )
                }
            }
            
            Spacer()
            
            if !reminder.isActive {
                SwiftUI.Image(systemName: "bell.slash")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            } else {
                SwiftUI.Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .opacity(reminder.isActive ? 1 : 0.6)
    }
}

// 笔记标题栏中的小提醒指示器
struct ReminderIndicator: View {
    let note: Note
    
    var body: some View {
        if note.hasActiveReminders, let nextReminder = note.nextReminder {
            HStack(spacing: 2) {
                SwiftUI.Image(systemName: "bell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(nextReminder.isOverdue ? .red : .blue)
                
                Text(nextReminder.isOverdue ? "已过期" : nextReminder.timeRemainingDescription)
                    .font(.caption)
                    .foregroundColor(nextReminder.isOverdue ? .red : .blue)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill((nextReminder.isOverdue ? Color(.systemRed) : Color(.systemBlue)).opacity(0.1))
            )
        }
    }
} 