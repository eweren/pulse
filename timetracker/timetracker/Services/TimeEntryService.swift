import Foundation
import CoreData

protocol TimeEntryServiceProtocol {
    func createTimeEntry(clientId: String, projectId: String, description: String) async throws -> TimeEntry
    func updateTimeEntry(_ entry: TimeEntry) async throws -> TimeEntry
    func deleteTimeEntry(id: String) async throws
    func getTimeEntries(clientId: String?, projectId: String?, dateRange: DateRange?) async throws -> [TimeEntry]
    func startTimer(clientId: String, projectId: String, description: String) async throws -> TimeEntry
    func stopTimer(entryId: String) async throws -> TimeEntry
    func addManualTimeEntry(clientId: String, projectId: String, description: String, startTime: Date, endTime: Date) async throws -> TimeEntry
    func getRunningEntries() async throws -> [TimeEntry]
}

class TimeEntryService: TimeEntryServiceProtocol, ObservableObject {
    private let persistenceController = PersistenceController.shared
    private let webhookService = WebhookService()
    private let validationService = ValidationService()
    
    func createTimeEntry(clientId: String, projectId: String, description: String) async throws -> TimeEntry {
        // Validate input
        try await validationService.validateTimeEntry(clientId: clientId, projectId: projectId, description: description)
        
        // Create time entry
        let entry = try await createTimeEntryEntity(
            clientId: clientId,
            projectId: projectId,
            entryDescription: description,
            startTime: Date(),
            isManual: false
        )
        
        // Trigger webhook
        await webhookService.triggerWebhook(event: .timeEntryCreated, data: entry)
        
        return entry
    }
    
    func addManualTimeEntry(clientId: String, projectId: String, description: String, startTime: Date, endTime: Date) async throws -> TimeEntry {
        // Validate input
        try await validationService.validateManualTimeEntry(
            clientId: clientId,
            projectId: projectId,
            description: description,
            startTime: startTime,
            endTime: endTime
        )
        
        // Calculate duration
        let duration = Int32(endTime.timeIntervalSince(startTime) / 60)
        
        // Create time entry
        let entry = try await createTimeEntryEntity(
            clientId: clientId,
            projectId: projectId,
            entryDescription: description,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            isManual: true
        )
        
        // Trigger webhook
        await webhookService.triggerWebhook(event: .timeEntryCreated, data: entry)
        
        return entry
    }
    
    func startTimer(clientId: String, projectId: String, description: String) async throws -> TimeEntry {
        // Stop any currently running timer
        try await stopAllRunningTimers()
        
        // Create new running timer without triggering timeEntryCreated webhook
        let entry = try await createTimeEntryEntity(
            clientId: clientId,
            projectId: projectId,
            entryDescription: description,
            startTime: Date(),
            isManual: false
        )
        entry.isRunning = true
        try await saveContext()
        
        // Trigger webhook for timer started (not timeEntryCreated)
        await webhookService.triggerWebhook(event: .timeEntryStarted, data: entry)
        
        return entry
    }
    
    func stopTimer(entryId: String) async throws -> TimeEntry {
        guard let entry = try await findTimeEntryById(entryId) else {
            throw TimeEntryError.notFound
        }
        
        entry.endTime = Date()
        entry.duration = Int32(entry.endTime!.timeIntervalSince(entry.startTime!) / 60)
        entry.isRunning = false
        entry.updatedAt = Date()
        
        try await saveContext()
        
        // Trigger webhooks for timer stopped and time entry created (since it's now persisted with final duration)
        await webhookService.triggerWebhook(event: .timeEntryStopped, data: entry)
        await webhookService.triggerWebhook(event: .timeEntryCreated, data: entry)
        
        return entry
    }
    
    func updateTimeEntry(_ entry: TimeEntry) async throws -> TimeEntry {
        // Recalculate duration if start and end times are set
        if let startTime = entry.startTime, let endTime = entry.endTime {
            entry.duration = Int32(endTime.timeIntervalSince(startTime) / 60)
            entry.isRunning = false
        }
        
        entry.updatedAt = Date()
        try await saveContext()
        
        // Trigger webhook
        await webhookService.triggerWebhook(event: .timeEntryUpdated, data: entry)
        
        return entry
    }
    
    func deleteTimeEntry(id: String) async throws {
        guard let entry = try await findTimeEntryById(id) else {
            throw TimeEntryError.notFound
        }
        
        // Trigger webhook before deletion
        await webhookService.triggerWebhook(event: .timeEntryDeleted, data: entry)
        
        persistenceController.container.viewContext.delete(entry)
        try await saveContext()
    }
    
    func getTimeEntries(clientId: String?, projectId: String?, dateRange: DateRange?) async throws -> [TimeEntry] {
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        var predicates: [NSPredicate] = []
        
        if let clientId = clientId {
            predicates.append(NSPredicate(format: "client.id == %@", clientId))
        }
        
        if let projectId = projectId {
            predicates.append(NSPredicate(format: "project.id == %@", projectId))
        }
        
        if let dateRange = dateRange {
            predicates.append(NSPredicate(format: "startTime >= %@ AND startTime <= %@", dateRange.start as NSDate, dateRange.end as NSDate))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TimeEntry.startTime, ascending: false)]
        
        return try persistenceController.container.viewContext.fetch(request)
    }
    
    func getRunningEntries() async throws -> [TimeEntry] {
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        request.predicate = NSPredicate(format: "isRunning == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TimeEntry.startTime, ascending: false)]
        
        return try persistenceController.container.viewContext.fetch(request)
    }
    
    // MARK: - Private Methods
    
    private func createTimeEntryEntity(
        clientId: String,
        projectId: String,
        entryDescription: String,
        startTime: Date,
        endTime: Date? = nil,
        duration: Int32 = 0,
        isManual: Bool
    ) async throws -> TimeEntry {
        let context = persistenceController.container.viewContext
        
        // Find client and project
        guard let client = try await findClientById(clientId),
              let project = try await findProjectById(projectId) else {
            throw TimeEntryError.clientOrProjectNotFound
        }
        
        // Create time entry
        let entry = TimeEntry(context: context)
        entry.id = UUID().uuidString
        entry.client = client
        entry.project = project
        entry.entryDescription = entryDescription
        entry.startTime = startTime
        entry.endTime = endTime
        entry.duration = duration
        entry.isRunning = endTime == nil
        entry.isManual = isManual
        entry.createdAt = Date()
        entry.updatedAt = Date()
        
        try await saveContext()
        return entry
    }
    
    private func findTimeEntryById(_ id: String) async throws -> TimeEntry? {
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        return try persistenceController.container.viewContext.fetch(request).first
    }
    
    private func findClientById(_ id: String) async throws -> Client? {
        let request: NSFetchRequest<Client> = Client.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        return try persistenceController.container.viewContext.fetch(request).first
    }
    
    private func findProjectById(_ id: String) async throws -> Project? {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        return try persistenceController.container.viewContext.fetch(request).first
    }
    
    private func stopAllRunningTimers() async throws {
        let runningEntries = try await getRunningEntries()
        for entry in runningEntries {
            entry.endTime = Date()
            entry.duration = Int32(entry.endTime!.timeIntervalSince(entry.startTime!) / 60)
            entry.isRunning = false
            entry.updatedAt = Date()
        }
        try await saveContext()
    }
    
    private func saveContext() async throws {
        let context = persistenceController.container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
}

// MARK: - Supporting Types

struct DateRange {
    let start: Date
    let end: Date
}

enum TimeEntryError: Error, LocalizedError {
    case notFound
    case invalidDuration
    case overlappingEntries
    case clientOrProjectNotFound
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Time entry not found"
        case .invalidDuration:
            return "Invalid duration"
        case .overlappingEntries:
            return "Overlapping time entries"
        case .clientOrProjectNotFound:
            return "Client or project not found"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        }
    }
}
