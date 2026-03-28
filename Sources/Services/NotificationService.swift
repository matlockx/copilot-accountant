import Foundation
import UserNotifications

/// Service for sending system notifications
class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    enum NotificationType {
        case threshold80
        case threshold90
        case customThreshold(Int)
        case percentageMilestone(Int)
        case resetSoon
        case apiError
        case test
    }
    
    /// Request notification permissions
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }
    
    /// Send a notification
    func sendNotification(type: NotificationType, currentUsage: Int, budget: Int) {
        let content = UNMutableNotificationContent()
        var trigger: UNNotificationTrigger?
        
        switch type {
        case .threshold80:
            content.title = "Budget Alert: 80% Used"
            content.body = "You've used \(currentUsage) of \(budget) premium requests (80%)"
            content.sound = .default
            
        case .threshold90:
            content.title = "⚠️ Budget Alert: 90% Used"
            content.body = "You've used \(currentUsage) of \(budget) premium requests (90%)"
            content.sound = .defaultCritical

        case .customThreshold(let percentage):
            content.title = "Budget Alert: \(percentage)% Used"
            content.body = "You've used \(currentUsage) of \(budget) premium requests (\(percentage)%)"
            content.sound = .default

        case .percentageMilestone(let percentage):
            content.title = "Usage Milestone: \(percentage)%"
            content.body = "You've reached \(percentage)% of your monthly budget (\(currentUsage) of \(budget) requests)."
            content.sound = .default
             
        case .resetSoon:
            content.title = "Budget Resets Tomorrow"
            content.body = "Your \(budget) premium requests will reset on the 1st"
            content.sound = .default
            
        case .apiError:
            content.title = "GitHub API Error"
            content.body = "Failed to fetch usage data. Check your connection and token."
            content.sound = .default

        case .test:
            content.title = "Copilot Accountant Test"
            content.body = "Notifications are working correctly on this Mac."
            content.sound = .default
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: NotificationSettingsConfiguration.testNotificationDelaySeconds, repeats: false)
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    /// Check if we're approaching reset date
    func shouldNotifyResetSoon() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let day = calendar.component(.day, from: now)
        
        // Notify on the last day of the month
        if let range = calendar.range(of: .day, in: .month, for: now) {
            return day == range.count
        }
        
        return false
    }
}
