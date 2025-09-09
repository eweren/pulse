import Foundation
import CoreData
import SwiftUI

protocol ClientServiceProtocol {
    func createClient(name: String, hourlyRate: Double, color: String, context: NSManagedObjectContext) async throws -> Client
    func updateClient(_ client: Client, context: NSManagedObjectContext) async throws -> Client
    func deleteClient(id: String, context: NSManagedObjectContext) async throws
    func getClients(context: NSManagedObjectContext) async throws -> [Client]
    func getClient(id: String, context: NSManagedObjectContext) async throws -> Client?
}

class ClientService: ClientServiceProtocol, ObservableObject {
    private let persistenceController = PersistenceController.shared
    private let validationService = ValidationService()
    private let webhookService = WebhookService()
    
    func createClient(name: String, hourlyRate: Double, color: String, context: NSManagedObjectContext) async throws -> Client {
        // Validate input
        try await validationService.validateClient(name: name, excludingClientId: nil)
        
        // Create client
        let client = Client(context: context)
        client.id = UUID().uuidString
        client.name = name
        client.hourlyRate = hourlyRate
        client.color = color
        client.isActive = true
        client.createdAt = Date()
        client.updatedAt = Date()
        
        try await saveContext(context)
        
        // Trigger webhook for client creation
        await webhookService.triggerWebhook(event: .clientCreated, data: client)
        
        return client
    }
    
    func updateClient(_ client: Client, context: NSManagedObjectContext) async throws -> Client {
        // Capture old values before updating
        let oldName = client.name ?? ""
        let oldHourlyRate = client.hourlyRate
        let oldColor = client.color ?? ""
        
        // Validate input, excluding the current client from duplicate check
        try await validationService.validateClient(name: client.name ?? "", excludingClientId: client.id)
        
        client.updatedAt = Date()
        try await saveContext(context)
        
        // Create update data with old and new values
        let updateData = ClientUpdateData(
            client: client,
            oldName: oldName,
            oldHourlyRate: oldHourlyRate,
            oldColor: oldColor
        )
        
        // Trigger webhook for client update
        await webhookService.triggerWebhook(event: .clientUpdated, data: updateData)
        
        return client
    }
    
    func deleteClient(id: String, context: NSManagedObjectContext) async throws {
        guard let client = try await findClientById(id, context: context) else {
            throw ClientError.notFound
        }
        
        // Check if client has active projects or time entries
        let hasActiveProjects = try await hasActiveProjects(clientId: id, context: context)
        let hasTimeEntries = try await hasTimeEntries(clientId: id, context: context)
        
        if hasActiveProjects || hasTimeEntries {
            // Soft delete - mark as inactive
            client.isActive = false
            client.updatedAt = Date()
        } else {
            // Hard delete
            context.delete(client)
        }
        
        try await saveContext(context)
    }
    
    func getClients(context: NSManagedObjectContext) async throws -> [Client] {
        let request: NSFetchRequest<Client> = Client.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Client.name, ascending: true)]
        
        return try context.fetch(request)
    }
    
    func getClient(id: String, context: NSManagedObjectContext) async throws -> Client? {
        return try await findClientById(id, context: context)
    }
    
    func getArchivedClients(context: NSManagedObjectContext) async throws -> [Client] {
        let request: NSFetchRequest<Client> = Client.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Client.name, ascending: true)]
        
        return try context.fetch(request)
    }
    
    func restoreClient(id: String, context: NSManagedObjectContext) async throws {
        guard let client = try await findClientById(id, context: context) else {
            throw ClientError.notFound
        }
        
        client.isActive = true
        client.updatedAt = Date()
        try await saveContext(context)
    }
    
    func permanentlyDeleteClient(id: String, context: NSManagedObjectContext) async throws {
        guard let client = try await findClientById(id, context: context) else {
            throw ClientError.notFound
        }
        
        // Only allow permanent deletion if client is already inactive
        guard !client.isActive else {
            throw ClientError.cannotPermanentlyDeleteActive
        }
        
        context.delete(client)
        try await saveContext(context)
    }
    
    // MARK: - Private Methods
    
    private func findClientById(_ id: String, context: NSManagedObjectContext) async throws -> Client? {
        let request: NSFetchRequest<Client> = Client.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }
    
    private func hasActiveProjects(clientId: String, context: NSManagedObjectContext) async throws -> Bool {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        request.predicate = NSPredicate(format: "client.id == %@ AND isActive == YES", clientId)
        request.fetchLimit = 1
        
        let count = try context.count(for: request)
        return count > 0
    }
    
    private func hasTimeEntries(clientId: String, context: NSManagedObjectContext) async throws -> Bool {
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        request.predicate = NSPredicate(format: "client.id == %@", clientId)
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

enum ClientError: Error, LocalizedError {
    case notFound
    case hasActiveProjects
    case hasTimeEntries
    case cannotPermanentlyDeleteActive
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Client not found"
        case .hasActiveProjects:
            return "Cannot delete client with active projects"
        case .hasTimeEntries:
            return "Cannot delete client with time entries"
        case .cannotPermanentlyDeleteActive:
            return "Cannot permanently delete an active client"
        }
    }
}
