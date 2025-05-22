//
//  ReminderListView.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import SwiftUI

struct ReminderListView: View {
    @ObservedObject var reminderViewModel: ReminderViewModel
    let note: Note
    
    @State private var showAddReminderSheet = false
    @State private var selectedReminder: Reminder?
    @State private var showEditReminderSheet = false
    
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
                                        selectedReminder = reminder
                                        showEditReminderSheet = true
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
                                        selectedReminder = reminder
                                        showEditReminderSheet = true
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
        }) {
            if let reminderToEdit = selectedReminder {
                ReminderSettingView(
                    reminderViewModel: reminderViewModel,
                    note: note,
                    existingReminder: reminderToEdit
                )
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