import Foundation
import CoreData

protocol ValidationServiceProtocol {
    func validateTimeEntry(clientId: String, projectId: String, description: String) async throws
    func validateManualTimeEntry(clientId: String, projectId: String, description: String, startTime: Date, endTime: Date) async throws
    func validateClient(name: String, excludingClientId: String?) async throws
    func validateProject(name: String, clientId: String, excludeProjectId: String?) async throws
    func validateWebhookConfig(name: String, url: String, events: [WebhookEvent]) async throws
}

class ValidationService: ValidationServiceProtocol {
    private let persistenceController = PersistenceController.shared
    
    func validateTimeEntry(clientId: String, projectId: String, description: String) async throws {
        // Validate required fields
        guard !clientId.isEmpty else {
            throw ValidationError.missingField("Client ID")
        }
        
        guard !projectId.isEmpty else {
            throw ValidationError.missingField("Project ID")
        }
        
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingField("Description")
        }
        
        // Validate client exists
        guard try await clientExists(id: clientId) else {
            throw ValidationError.clientNotFound
        }
        
        // Validate project exists
        guard try await projectExists(id: projectId) else {
            throw ValidationError.projectNotFound
        }
        
        // Validate project belongs to client
        guard try await projectBelongsToClient(projectId: projectId, clientId: clientId) else {
            throw ValidationError.projectDoesNotBelongToClient
        }
    }
    
    func validateManualTimeEntry(clientId: String, projectId: String, description: String, startTime: Date, endTime: Date) async throws {
        // Validate basic time entry
        try await validateTimeEntry(clientId: clientId, projectId: projectId, description: description)
        
        // Validate time range
        guard endTime > startTime else {
            throw ValidationError.invalidTimeRange
        }
        
        // Validate duration (not too long - e.g., max 24 hours)
        let duration = endTime.timeIntervalSince(startTime)
        guard duration <= 24 * 60 * 60 else {
            throw ValidationError.durationTooLong
        }
        
        // Validate not in the future
        guard startTime <= Date() else {
            throw ValidationError.startTimeInFuture
        }
        
        // Check for overlapping entries
        try await validateNoOverlappingEntries(clientId: clientId, startTime: startTime, endTime: endTime)
    }
    
    func validateClient(name: String, excludingClientId: String?) async throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingField("Client name")
        }
        
        guard name.count <= 100 else {
            throw ValidationError.fieldTooLong("Client name", maxLength: 100)
        }
        
        // Check for duplicate names
        guard try await !clientNameExists(name: name, excludingClientId: excludingClientId) else {
            throw ValidationError.duplicateClientName
        }
    }
    
    func validateProject(name: String, clientId: String, excludeProjectId: String? = nil) async throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingField("Project name")
        }
        
        guard name.count <= 100 else {
            throw ValidationError.fieldTooLong("Project name", maxLength: 100)
        }
        
        guard !clientId.isEmpty else {
            throw ValidationError.missingField("Client ID")
        }
        
        // Validate client exists
        guard try await clientExists(id: clientId) else {
            throw ValidationError.clientNotFound
        }
        
        // Check for duplicate project names within the same client
        guard try await !projectNameExists(name: name, clientId: clientId, excludeProjectId: excludeProjectId) else {
            throw ValidationError.duplicateProjectName
        }
    }
    
    func validateWebhookConfig(name: String, url: String, events: [WebhookEvent]) async throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingField("Webhook name")
        }
        
        guard name.count <= 100 else {
            throw ValidationError.fieldTooLong("Webhook name", maxLength: 100)
        }
        
        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingField("Webhook URL")
        }
        
        // Validate URL format
        guard let urlObj = URL(string: url), urlObj.scheme != nil else {
            throw ValidationError.invalidURL
        }
        
        // Enforce HTTPS
        guard urlObj.scheme?.lowercased() == "https" else {
            throw ValidationError.httpsRequired
        }
        
        guard !events.isEmpty else {
            throw ValidationError.missingField("Webhook events")
        }
        
        // Check for duplicate webhook names
        guard try await !webhookNameExists(name: name) else {
            throw ValidationError.duplicateWebhookName
        }
    }
    
    // MARK: - Private Validation Methods
    
    private func clientExists(id: String) async throws -> Bool {
        let request: NSFetchRequest<Client> = Client.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        let count = try persistenceController.container.viewContext.count(for: request)
        return count > 0
    }
    
    private func projectExists(id: String) async throws -> Bool {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        let count = try persistenceController.container.viewContext.count(for: request)
        return count > 0
    }
    
    private func projectBelongsToClient(projectId: String, clientId: String) async throws -> Bool {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND client.id == %@", projectId, clientId)
        request.fetchLimit = 1
        
        let count = try persistenceController.container.viewContext.count(for: request)
        return count > 0
    }
    
    private func clientNameExists(name: String, excludingClientId: String? = nil) async throws -> Bool {
        let request: NSFetchRequest<Client> = Client.fetchRequest()
        
        var predicateFormat = "name ==[c] %@"
        var predicateArgs: [Any] = [name]
        
        if let excludingId = excludingClientId {
            predicateFormat += " AND id != %@"
            predicateArgs.append(excludingId)
        }
        
        request.predicate = NSPredicate(format: predicateFormat, argumentArray: predicateArgs)
        request.fetchLimit = 1
        
        let count = try persistenceController.container.viewContext.count(for: request)
        return count > 0
    }
    
    private func projectNameExists(name: String, clientId: String, excludeProjectId: String? = nil) async throws -> Bool {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        
        var predicateFormat = "name ==[c] %@ AND client.id == %@"
        var predicateArgs: [Any] = [name, clientId]
        
        if let excludeId = excludeProjectId {
            predicateFormat += " AND id != %@"
            predicateArgs.append(excludeId)
        }
        
        request.predicate = NSPredicate(format: predicateFormat, argumentArray: predicateArgs)
        request.fetchLimit = 1
        
        let count = try persistenceController.container.viewContext.count(for: request)
        return count > 0
    }
    
    private func webhookNameExists(name: String) async throws -> Bool {
        let request: NSFetchRequest<WebhookConfig> = WebhookConfig.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1
        
        let count = try persistenceController.container.viewContext.count(for: request)
        return count > 0
    }
    
    private func validateNoOverlappingEntries(clientId: String, startTime: Date, endTime: Date) async throws {
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "client.id == %@ AND ((startTime <= %@ AND endTime >= %@) OR (startTime <= %@ AND endTime >= %@) OR (startTime >= %@ AND endTime <= %@))",
            clientId,
            startTime as NSDate, startTime as NSDate,
            endTime as NSDate, endTime as NSDate,
            startTime as NSDate, endTime as NSDate
        )
        
        let count = try persistenceController.container.viewContext.count(for: request)
        if count > 0 {
            throw ValidationError.overlappingTimeEntries
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: Error, LocalizedError {
    case missingField(String)
    case fieldTooLong(String, maxLength: Int)
    case clientNotFound
    case projectNotFound
    case projectDoesNotBelongToClient
    case duplicateClientName
    case duplicateProjectName
    case duplicateWebhookName
    case invalidTimeRange
    case durationTooLong
    case startTimeInFuture
    case overlappingTimeEntries
    case invalidURL
    case httpsRequired
    
    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "\(field) is required"
        case .fieldTooLong(let field, let maxLength):
            return "\(field) is too long (maximum \(maxLength) characters)"
        case .clientNotFound:
            return "Client not found"
        case .projectNotFound:
            return "Project not found"
        case .projectDoesNotBelongToClient:
            return "Project does not belong to the specified client"
        case .duplicateClientName:
            return "A client with this name already exists"
        case .duplicateProjectName:
            return "A project with this name already exists for this client"
        case .duplicateWebhookName:
            return "A webhook with this name already exists"
        case .invalidTimeRange:
            return "End time must be after start time"
        case .durationTooLong:
            return "Time entry duration cannot exceed 24 hours"
        case .startTimeInFuture:
            return "Start time cannot be in the future"
        case .overlappingTimeEntries:
            return "Time entry overlaps with existing entries"
        case .invalidURL:
            return "Invalid URL format"
        case .httpsRequired:
            return "Webhook URL must use HTTPS"
        }
    }
}
