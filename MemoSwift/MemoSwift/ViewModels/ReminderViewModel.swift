//
//  ReminderViewModel.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import Foundation
import CoreData
import SwiftUI
import UserNotifications

class ReminderViewModel: ObservableObject {
    let viewContext: NSManagedObjectContext
    weak var noteViewModel: NoteViewModel?
    
    // 提醒更新触发器
    @Published var reminderUpdated = UUID()
    
    // 记录已安排的通知ID以便更新
    private var scheduledNotifications: [String: String] = [:]
    
    init(viewContext: NSManagedObjectContext, noteViewModel: NoteViewModel? = nil) {
        self.viewContext = viewContext
        self.noteViewModel = noteViewModel
        
        // 请求通知权限
        requestNotificationPermission()
    }
    
    // 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("请求通知权限时出错: \(error.localizedDescription)")
            }
            
            if granted {
                print("用户已授予通知权限")
                // 初始化加载所有提醒并设置通知
                DispatchQueue.main.async {
                    self.loadAndScheduleAllActiveReminders()
                }
            } else {
                print("用户拒绝了通知权限")
            }
        }
    }
    
    // 创建新提醒
    @discardableResult
    func createReminder(for note: Note, title: String, date: Date, repeatType: Reminder.RepeatType = .none) -> Reminder {
        let newReminder = Reminder(context: viewContext)
        newReminder.id = UUID()
        newReminder.title = title
        
        // 确保明确设置reminderDate，不依赖默认值
        newReminder.reminderDate = date  
        
        newReminder.createdAt = Date()
        newReminder.isActive = true
        newReminder.repeatType = repeatType.rawValue
        newReminder.note = note
        
        // 将提醒添加到笔记
        note.addReminder(newReminder)
        
        saveContext()
        reminderUpdated = UUID()
        
        // 安排本地通知
        scheduleNotification(for: newReminder)
        
        return newReminder
    }
    
    // 更新现有提醒
    func updateReminder(reminder: Reminder, title: String, date: Date, isActive: Bool, repeatType: Reminder.RepeatType) {
        // 更新提醒信息
        reminder.title = title
        reminder.reminderDate = date
        reminder.isActive = isActive
        reminder.repeatType = repeatType.rawValue
        
        saveContext()
        reminderUpdated = UUID()
        
        // 取消并重新安排通知
        if isActive {
            cancelNotification(for: reminder)
            scheduleNotification(for: reminder)
        } else {
            cancelNotification(for: reminder)
        }
    }
    
    // 删除提醒
    func deleteReminder(reminder: Reminder) {
        // 先取消通知
        cancelNotification(for: reminder)
        
        // 从笔记中移除提醒
        if let note = reminder.note {
            note.removeReminder(reminder)
        }
        
        // 删除提醒
        viewContext.delete(reminder)
        saveContext()
        reminderUpdated = UUID()
    }
    
    // 安排本地通知
    private func scheduleNotification(for reminder: Reminder) {
        guard reminder.isActive else { return }
        
        // 获取当前日期和提醒日期
        let now = Date()
        let reminderDate = reminder.wrappedReminderDate
        
        // 如果提醒日期已过，且不是重复提醒，则不需要设置通知
        if reminderDate < now && reminder.wrappedRepeatType == .none {
            return
        }
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "备忘提醒"
        content.subtitle = reminder.title
        
        if let note = reminder.note {
            content.body = note.wrappedTitle
            
            // 添加用户信息以便点击通知时打开对应笔记
            content.userInfo = [
                "noteId": note.id?.uuidString ?? "",
                "reminderId": reminder.id?.uuidString ?? ""
            ]
        } else {
            content.body = "点击查看详情"
        }
        
        content.sound = .default
        content.badge = 1
        
        // 创建触发器
        var targetDate = reminderDate
        if reminderDate < now {
            // 如果是过期的重复提醒，计算下一次时间
            if let nextDate = reminder.calculateNextReminderDate() {
                targetDate = nextDate
            } else {
                return
            }
        }
        
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: targetDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        // 创建通知请求
        let identifier = "reminder-\(reminder.wrappedId.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // 记录通知ID
        if let reminderId = reminder.id?.uuidString {
            scheduledNotifications[reminderId] = identifier
        }
        
        // 添加通知请求
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("添加通知请求时出错: \(error.localizedDescription)")
            } else {
                print("成功安排提醒通知: \(reminder.title), 时间: \(reminder.formattedReminderDate)")
            }
        }
    }
    
    // 取消已安排的通知
    private func cancelNotification(for reminder: Reminder) {
        guard let reminderId = reminder.id?.uuidString,
              let notificationId = scheduledNotifications[reminderId] else {
            // 如果没有找到对应的通知ID，使用通用标识符
            let fallbackId = "reminder-\(reminder.wrappedId.uuidString)"
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [fallbackId])
            return
        }
        
        // 取消通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        // 从记录中移除
        scheduledNotifications.removeValue(forKey: reminderId)
    }
    
    // 加载所有活动提醒并设置通知
    func loadAndScheduleAllActiveReminders() {
        let fetchRequest = Reminder.fetchActiveReminders()
        do {
            let activeReminders = try viewContext.fetch(fetchRequest)
            
            // 先清除所有待处理的通知
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            scheduledNotifications.removeAll()
            
            // 重新安排所有活动提醒的通知
            for reminder in activeReminders {
                scheduleNotification(for: reminder)
            }
            
            print("已重新安排 \(activeReminders.count) 个提醒的通知")
        } catch {
            print("加载活动提醒时出错: \(error.localizedDescription)")
        }
    }
    
    // 处理提醒到期后的重复提醒设置
    func handleReminderTriggered(reminderId: UUID) {
        // 查找提醒
        let fetchRequest: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", reminderId as CVarArg)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            guard let reminder = results.first else { return }
            
            // 检查是否是重复提醒
            if reminder.wrappedRepeatType != .none {
                // 计算下一次提醒时间
                if let nextDate = reminder.calculateNextReminderDate() {
                    // 更新提醒日期
                    reminder.reminderDate = nextDate
                    saveContext()
                    
                    // 重新安排通知
                    scheduleNotification(for: reminder)
                    print("已为重复提醒安排下一次通知: \(reminder.title), 下次时间: \(reminder.formattedReminderDate)")
                }
            }
        } catch {
            print("处理已触发提醒时出错: \(error.localizedDescription)")
        }
    }
    
    // 获取特定笔记的所有提醒
    func fetchRemindersForNote(note: Note) -> [Reminder] {
        let fetchRequest = Reminder.fetchRemindersForNote(note: note)
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("获取笔记提醒时出错: \(error.localizedDescription)")
            return []
        }
    }
    
    // 获取所有活动提醒
    func fetchAllActiveReminders() -> [Reminder] {
        let fetchRequest = Reminder.fetchActiveReminders()
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("获取所有活动提醒时出错: \(error.localizedDescription)")
            return []
        }
    }
    
    // 获取即将到期的提醒（24小时内）
    func fetchUpcomingReminders() -> [Reminder] {
        let fetchRequest = Reminder.fetchUpcomingReminders()
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("获取即将到期提醒时出错: \(error.localizedDescription)")
            return []
        }
    }
    
    // 获取已过期的提醒
    func fetchOverdueReminders() -> [Reminder] {
        let fetchRequest = Reminder.fetchOverdueReminders()
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("获取已过期提醒时出错: \(error.localizedDescription)")
            return []
        }
    }
    
    // 保存上下文
    private func saveContext() {
        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        } catch {
            let nsError = error as NSError
            print("保存上下文时出错: \(nsError), \(nsError.userInfo)")
        }
    }
} 