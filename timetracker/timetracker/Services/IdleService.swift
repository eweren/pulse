import Foundation
import AppKit
import Combine

private let idleDetectionEnabledKey = "idleDetectionEnabled"
private let idleTimeoutMinutesKey = "idleTimeoutMinutes"

enum IdleServiceSettings {
    static var idleDetectionEnabled: Bool {
        get { UserDefaults.standard.object(forKey: idleDetectionEnabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: idleDetectionEnabledKey) }
    }
    
    static var idleTimeoutMinutes: Int {
        get {
            let v = UserDefaults.standard.object(forKey: idleTimeoutMinutesKey) as? Int
            return v ?? 15
        }
        set { UserDefaults.standard.set(newValue, forKey: idleTimeoutMinutesKey) }
    }
}

/// Polls system idle time and stops the running timer when idle exceeds the configured threshold.
final class IdleService: ObservableObject {
    private var timer: Timer?
    private let timerService: TimerService
    private var cancellables = Set<AnyCancellable>()
    
    init(timerService: TimerService) {
        self.timerService = timerService
    }
    
    func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkIdleAndStopIfNeeded()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkIdleAndStopIfNeeded() {
        guard IdleServiceSettings.idleDetectionEnabled else { return }
        guard let currentTimer = timerService.currentTimer else { return }
        let timeoutSeconds = TimeInterval(IdleServiceSettings.idleTimeoutMinutes) * 60
        let idleSeconds = systemIdleTime()
        guard idleSeconds >= timeoutSeconds else { return }
        
        let entryId = currentTimer.id ?? ""
        Task { @MainActor in
            let timeEntryService = TimeEntryService()
            do {
                _ = try await timeEntryService.stopTimer(entryId: entryId)
                self.timerService.stopTimer()
            } catch {
                print("IdleService: failed to stop timer: \(error)")
            }
        }
    }
    
    /// Returns system idle time in seconds (keyboard/mouse).
    private func systemIdleTime() -> TimeInterval {
        let stateId = CGEventSourceStateID.combinedSessionState
        // Use a proxy for "any input": tapDisabledByUserInput matches kCGAnyInputEventType behavior
        return CGEventSource.secondsSinceLastEventType(stateId, eventType: .tapDisabledByUserInput)
    }
}
