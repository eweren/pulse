//
//  timetrackerApp.swift
//  timetracker
//
//  Created by Nico Hülscher on 07.09.25.
//

import SwiftUI
import CoreData

@main
struct timetrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var timerService = TimerService()
    @StateObject private var statusBarManager = StatusBarManager()
    @StateObject private var autoStartService = AutoStartService()
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .onAppear {
                    // Initialize the status bar manager when the app starts
                    statusBarManager.setTimerService(timerService)
                    statusBarManager.setAutoStartService(autoStartService)
                    // Hide the main window immediately
                    DispatchQueue.main.async {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
        
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(timerService)
                .environmentObject(autoStartService)
        }
    }
}

// MARK: - Persistence Controller
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "EnhancedTimeTracker")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Preview
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let client = Client(context: viewContext)
        client.id = UUID().uuidString
        client.name = "Sample Client"
        client.hourlyRate = 75.0
        client.color = "#007AFF"
        client.isActive = true
        client.createdAt = Date()
        client.updatedAt = Date()
        
        let project = Project(context: viewContext)
        project.id = UUID().uuidString
        project.name = "Sample Project"
        project.projectDescription = "A sample project for previews"
        project.hourlyRate = 80.0
        project.isActive = true
        project.client = client
        project.createdAt = Date()
        project.updatedAt = Date()
        
        let timeEntry = TimeEntry(context: viewContext)
        timeEntry.id = UUID().uuidString
        timeEntry.client = client
        timeEntry.project = project
        timeEntry.entryDescription = "Working on sample feature"
        timeEntry.startTime = Date().addingTimeInterval(-3600) // 1 hour ago
        timeEntry.endTime = Date()
        timeEntry.duration = 60
        timeEntry.isRunning = false
        timeEntry.isManual = false
        timeEntry.createdAt = Date()
        timeEntry.updatedAt = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return result
    }()
}
