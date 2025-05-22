//
//  Reminder.swift
//  MemoSwift
//
//  Created by T-Mux on 5/2/25.
//

import Foundation
import CoreData

@objc(Reminder)
public class Reminder: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String
    @NSManaged public var reminderDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var repeatType: String
    @NSManaged public var note: Note?
    
    // 在awakeFromInsert中确保reminderDate有值
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // 设置默认值
        if id == nil {
            id = UUID()
        }
        
        // 确保reminderDate有值，设置为当前时间
        if reminderDate == nil {
            reminderDate = Date().addingTimeInterval(3600) // 默认设置为1小时后
        }
        
        // 设置其他属性的默认值
        if createdAt == nil {
            createdAt = Date()
        }
    }
    
    // 重复类型枚举
    public enum RepeatType: String, CaseIterable, Identifiable {
        case none = "none"            // 不重复
        case daily = "daily"          // 每天
        case weekly = "weekly"        // 每周
        case monthly = "monthly"      // 每月
        case yearly = "yearly"        // 每年
        case weekdays = "weekdays"    // 工作日
        case weekends = "weekends"    // 周末
        
        public var id: String { self.rawValue }
        
        public var displayName: String {
            switch self {
            case .none: return "不重复"
            case .daily: return "每天"
            case .weekly: return "每周"
            case .monthly: return "每月"
            case .yearly: return "每年"
            case .weekdays: return "工作日"
            case .weekends: return "周末"
            }
        }
        
        // 获取下一个提醒日期
        public func nextDate(after date: Date) -> Date? {
            let calendar = Calendar.current
            
            switch self {
            case .none:
                return nil // 不重复
                
            case .daily:
                return calendar.date(byAdding: .day, value: 1, to: date)
                
            case .weekly:
                return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
                
            case .monthly:
                return calendar.date(byAdding: .month, value: 1, to: date)
                
            case .yearly:
                return calendar.date(byAdding: .year, value: 1, to: date)
                
            case .weekdays:
                // 找到下一个工作日
                var nextDate = calendar.date(byAdding: .day, value: 1, to: date)!
                let weekday = calendar.component(.weekday, from: nextDate)
                
                // 如果是周六，跳到下周一
                if weekday == 7 { // 周六
                    nextDate = calendar.date(byAdding: .day, value: 2, to: nextDate)!
                } 
                // 如果是周日，跳到周一
                else if weekday == 1 { // 周日
                    nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
                }
                
                return nextDate
                
            case .weekends:
                // 找到下一个周末日期
                var nextDate = calendar.date(byAdding: .day, value: 1, to: date)!
                let weekday = calendar.component(.weekday, from: nextDate)
                
                // 如果是周一到周五，跳到周六
                if weekday >= 2 && weekday <= 6 {
                    // 计算到周六的天数
                    let daysUntilWeekend = 7 - weekday + 1
                    nextDate = calendar.date(byAdding: .day, value: daysUntilWeekend, to: nextDate)!
                }
                
                return nextDate
            }
        }
    }
    
    // 获取包装后的ID
    public var wrappedId: UUID {
        id ?? UUID()
    }
    
    // 获取包装后的提醒日期
    public var wrappedReminderDate: Date {
        reminderDate ?? Date().addingTimeInterval(3600) // 默认为1小时后
    }
    
    // 获取包装后的创建日期
    public var wrappedCreatedAt: Date {
        createdAt ?? Date()
    }
    
    // 获取包装后的重复类型
    public var wrappedRepeatType: RepeatType {
        RepeatType(rawValue: repeatType) ?? .none
    }
    
    // 格式化提醒日期显示
    public var formattedReminderDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: wrappedReminderDate)
    }
    
    // 检查提醒是否过期
    public var isOverdue: Bool {
        return isActive && wrappedReminderDate < Date()
    }
    
    // 获取到提醒时间的剩余时间描述
    public var timeRemainingDescription: String {
        let now = Date()
        if wrappedReminderDate < now {
            return "已过期"
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: wrappedReminderDate)
        
        if let days = components.day, days > 0 {
            return "\(days)天后"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)小时后"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分钟后"
        } else {
            return "即将提醒"
        }
    }
    
    // 计算下一次提醒时间
    public func calculateNextReminderDate() -> Date? {
        return wrappedRepeatType.nextDate(after: wrappedReminderDate)
    }
}

extension Reminder {
    // 创建基本的 fetchRequest
    static func fetchRequest() -> NSFetchRequest<Reminder> {
        return NSFetchRequest<Reminder>(entityName: "Reminder")
    }
    
    // 获取所有活动提醒
    static func fetchActiveReminders() -> NSFetchRequest<Reminder> {
        let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reminder.reminderDate, ascending: true)]
        return request
    }
    
    // 获取特定笔记的提醒
    static func fetchRemindersForNote(note: Note) -> NSFetchRequest<Reminder> {
        let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        request.predicate = NSPredicate(format: "note == %@", note)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reminder.reminderDate, ascending: true)]
        return request
    }
    
    // 获取即将到期的提醒（未来24小时内）
    static func fetchUpcomingReminders() -> NSFetchRequest<Reminder> {
        let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        request.predicate = NSPredicate(format: "isActive == YES AND reminderDate >= %@ AND reminderDate <= %@", now as NSDate, tomorrow as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reminder.reminderDate, ascending: true)]
        return request
    }
    
    // 获取所有过期的提醒
    static func fetchOverdueReminders() -> NSFetchRequest<Reminder> {
        let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        let now = Date()
        request.predicate = NSPredicate(format: "isActive == YES AND reminderDate < %@", now as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Reminder.reminderDate, ascending: true)]
        return request
    }
} 