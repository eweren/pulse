import Foundation
import CoreData
import SwiftUI

class TimerService: ObservableObject {
    @Published var currentTimer: TimeEntry?
    @Published var elapsedTime: TimeInterval = 0
    @Published var statusBarTitle: String = ""
    
    private var timer: Timer?
    private let persistenceController = PersistenceController.shared
    private var isViewVisible: Bool = false
    
    init() {
        loadCurrentTimer()
    }
    
    func loadCurrentTimer() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        request.predicate = NSPredicate(format: "isRunning == YES")
        request.fetchLimit = 1
        
        do {
            let runningTimers = try context.fetch(request)
            Task { @MainActor in
                self.currentTimer = runningTimers.first
                
                if let timer = self.currentTimer, let startTime = timer.startTime {
                    self.elapsedTime = Date().timeIntervalSince(startTime)
                    self.updateStatusBarTitle()
                    self.startTimer()
                } else {
                    self.updateStatusBarTitle()
                }
            }
        } catch {
            print("Error loading current timer: \(error)")
        }
    }
    
    func startTimer(for timeEntry: TimeEntry) {
        Task { @MainActor in
            self.currentTimer = timeEntry
            if let startTime = timeEntry.startTime {
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
            self.updateStatusBarTitle()
            self.startTimer()
        }
    }
    
    func stopTimer() {
        Task { @MainActor in
            self.currentTimer = nil
            self.elapsedTime = 0
            self.updateStatusBarTitle()
            self.stopTimerTick()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        
        // Use 1-second interval when view is visible, 1-minute when hidden for battery optimization
        let interval: TimeInterval = isViewVisible ? 1.0 : 60.0
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if let startTime = self.currentTimer?.startTime {
                Task { @MainActor in
                    self.elapsedTime = Date().timeIntervalSince(startTime)
                    self.updateStatusBarTitle()
                }
            }
        }
    }
    
    private func stopTimerTick() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - View Visibility Control
    
    func setViewVisible(_ visible: Bool) {
        guard isViewVisible != visible else { return }
        
        isViewVisible = visible
        
        // Restart timer with appropriate interval if we have a running timer
        if currentTimer != nil {
            startTimer()
        }
    }
    
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        
        // Always show hours and minutes in HH:MM format
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    var formattedElapsedTimeWithSeconds: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        // Show hours, minutes, and seconds in HH:MM:SS format
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func updateStatusBarTitle() {
        Task { @MainActor in
            guard let timer = self.currentTimer else {
                self.statusBarTitle = ""
                return
            }
            
            let projectName = timer.project?.name ?? "Unknown Project"
            self.statusBarTitle = "\(projectName) - \(self.formattedElapsedTime)"
        }
    }
}
