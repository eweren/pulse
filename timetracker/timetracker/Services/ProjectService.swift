import Foundation
import CoreData
import SwiftUI

protocol ProjectServiceProtocol {
    func createProject(name: String, description: String?, clientId: String, hourlyRate: Double?, context: NSManagedObjectContext) async throws -> Project
    func updateProject(_ project: Project, context: NSManagedObjectContext) async throws -> Project
    func deleteProject(id: String, context: NSManagedObjectContext) async throws
    func getProjects(clientId: String?, context: NSManagedObjectContext) async throws -> [Project]
    func getProject(id: String, context: NSManagedObjectContext) async throws -> Project?
}

class ProjectService: ProjectServiceProtocol, ObservableObject {
    private let persistenceController = PersistenceController.shared
    private let validationService = ValidationService()
    private let webhookService = WebhookService()
    
    func createProject(name: String, description: String?, clientId: String, hourlyRate: Double?, context: NSManagedObjectContext) async throws -> Project {
        // Validate input
        try await validationService.validateProject(name: name, clientId: clientId)
        
        // Create project
        let project = Project(context: context)
        project.id = UUID().uuidString
        project.name = name
        project.projectDescription = description
        project.hourlyRate = hourlyRate ?? 0.0
        project.isActive = true
        project.createdAt = Date()
        project.updatedAt = Date()
        
        // Set client relationship
        if let client = try await findClientById(clientId, context: context) {
            project.client = client
        } else {
            throw ProjectError.clientNotFound
        }
        
        try await saveContext(context)
        
        // Trigger webhook for project creation
        await webhookService.triggerWebhook(event: .projectCreated, data: project)
        
        return project
    }
    
    func updateProject(_ project: Project, context: NSManagedObjectContext) async throws -> Project {
        // Capture old values before updating
        let oldName = project.name ?? ""
        let oldDescription = project.projectDescription ?? ""
        let oldHourlyRate = project.hourlyRate
        
        // Validate input
        try await validationService.validateProject(name: project.name ?? "", clientId: project.client?.id ?? "", excludeProjectId: project.id)
        
        project.updatedAt = Date()
        try await saveContext(context)
        
        // Create update data with old and new values
        let updateData = ProjectUpdateData(
            project: project,
            oldName: oldName,
            oldDescription: oldDescription,
            oldHourlyRate: oldHourlyRate
        )
        
        // Trigger webhook for project update
        await webhookService.triggerWebhook(event: .projectUpdated, data: updateData)
        
        return project
    }
    
    func deleteProject(id: String, context: NSManagedObjectContext) async throws {
        guard let project = try await findProjectById(id, context: context) else {
            throw ProjectError.notFound
        }
        
        // Check if project has time entries
        let hasTimeEntries = try await hasTimeEntries(projectId: id, context: context)
        
        if hasTimeEntries {
            // Soft delete - mark as inactive
            project.isActive = false
            project.updatedAt = Date()
        } else {
            // Hard delete
            context.delete(project)
        }
        
        try await saveContext(context)
    }
    
    func getProjects(clientId: String?, context: NSManagedObjectContext) async throws -> [Project] {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        
        if let clientId = clientId {
            request.predicate = NSPredicate(format: "client.id == %@ AND isActive == YES", clientId)
        } else {
            request.predicate = NSPredicate(format: "isActive == YES")
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Project.name, ascending: true)]
        
        return try context.fetch(request)
    }
    
    func getProject(id: String, context: NSManagedObjectContext) async throws -> Project? {
        return try await findProjectById(id, context: context)
    }
    
    func getArchivedProjects(context: NSManagedObjectContext) async throws -> [Project] {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Project.name, ascending: true)]
        
        return try context.fetch(request)
    }
    
    func restoreProject(id: String, context: NSManagedObjectContext) async throws {
        guard let project = try await findProjectById(id, context: context) else {
            throw ProjectError.notFound
        }
        
        project.isActive = true
        project.updatedAt = Date()
        try await saveContext(context)
    }
    
    func permanentlyDeleteProject(id: String, context: NSManagedObjectContext) async throws {
        guard let project = try await findProjectById(id, context: context) else {
            throw ProjectError.notFound
        }
        
        // Only allow permanent deletion if project is already inactive
        guard !project.isActive else {
            throw ProjectError.cannotPermanentlyDeleteActive
        }
        
        context.delete(project)
        try await saveContext(context)
    }
    
    // MARK: - Private Methods
    
    private func findProjectById(_ id: String, context: NSManagedObjectContext) async throws -> Project? {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }
    
    private func findClientById(_ id: String, context: NSManagedObjectContext) async throws -> Client? {
        let request: NSFetchRequest<Client> = Client.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }
    
    private func hasTimeEntries(projectId: String, context: NSManagedObjectContext) async throws -> Bool {
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        request.predicate = NSPredicate(format: "project.id == %@", projectId)
        request.fetchLimit = 1
        
        let count = try context.count(for: request)
        return count > 0
    }
    
    private func saveContext(_ context: NSManagedObjectContext) async throws {
        if context.hasChanges {
            try context.save()
        }
    }
}

enum ProjectError: Error, LocalizedError {
    case notFound
    case clientNotFound
    case hasTimeEntries
    case cannotPermanentlyDeleteActive
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Project not found"
        case .clientNotFound:
            return "Client not found"
        case .hasTimeEntries:
            return "Cannot delete project with time entries"
        case .cannotPermanentlyDeleteActive:
            return "Cannot permanently delete an active project"
        }
    }
}
