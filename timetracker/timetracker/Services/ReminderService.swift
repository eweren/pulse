import Foundation
import UserNotifications
import Combine

private let reminderEnabledKey = "reminderEnabled"
private let reminderAfterHoursKey = "reminderAfterHours"
private let reminderNotificationIdentifier = "runningTimerReminder"

enum ReminderServiceSettings {
    static var reminderEnabled: Bool {
        get { UserDefaults.standard.object(forKey: reminderEnabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: reminderEnabledKey) }
    }
    
    static var reminderAfterHours: Double {
        get {
            let v = UserDefaults.standard.double(forKey: reminderAfterHoursKey)
            return v > 0 ? v : 4.0
        }
        set { UserDefaults.standard.set(newValue, forKey: reminderAfterHoursKey) }
    }
}

final class ReminderService: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let timerService: TimerService
    
    init(timerService: TimerService) {
        self.timerService = timerService
        timerService.$currentTimer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entry in
                self?.handleTimerChange(entry)
            }
            .store(in: &cancellables)
    }
    
    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }
    
    private func handleTimerChange(_ entry: TimeEntry?) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderNotificationIdentifier])
        guard let entry = entry else { return }
        guard ReminderServiceSettings.reminderEnabled else { return }
        let hours = ReminderServiceSettings.reminderAfterHours
        guard hours > 0 else { return }
        
        let content = UNMutableNotificationContent()
        let projectName = entry.project?.name ?? "Unknown Project"
        content.title = "Timer still running"
        content.body = "Timer has been running for \(Int(hours)) hours on \(projectName)."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: hours * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: reminderNotificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("ReminderService: failed to schedule notification: \(error)")
            }
        }
    }
}
