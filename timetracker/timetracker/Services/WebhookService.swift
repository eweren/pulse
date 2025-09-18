import Foundation
import CoreData
import CryptoKit

protocol WebhookServiceProtocol {
    func createWebhook(_ config: WebhookConfig) async throws -> WebhookConfig
    func createWebhook(
        name: String,
        url: String,
        secret: String?,
        events: String,
        isActive: Bool,
        retryAttempts: Int32,
        timeout: Int32
    ) async throws -> WebhookConfig
    func updateWebhook(_ config: WebhookConfig) async throws -> WebhookConfig
    func deleteWebhook(id: String) async throws
    func getWebhooks() async throws -> [WebhookConfig]
    func triggerWebhook(event: WebhookEvent, data: Any) async
}

class WebhookService: WebhookServiceProtocol, ObservableObject {
    private let persistenceController = PersistenceController.shared
    private let deliveryQueue = DispatchQueue(label: "webhook.delivery", qos: .background)
    private let networkClient = NetworkClient()
    
    func createWebhook(_ config: WebhookConfig) async throws -> WebhookConfig {
        let context = persistenceController.container.viewContext
        
        let webhook = WebhookConfig(context: context)
        webhook.id = UUID().uuidString
        webhook.name = config.name
        webhook.url = config.url
        webhook.secret = config.secret
        webhook.events = config.events
        webhook.isActive = config.isActive
        webhook.retryAttempts = config.retryAttempts
        webhook.timeout = config.timeout
        webhook.createdAt = Date()
        webhook.updatedAt = Date()
        
        try await saveContext()
        return webhook
    }
    
    func createWebhook(
        name: String,
        url: String,
        secret: String?,
        events: String,
        isActive: Bool,
        retryAttempts: Int32,
        timeout: Int32
    ) async throws -> WebhookConfig {
        let context = persistenceController.container.viewContext
        
        let webhook = WebhookConfig(context: context)
        webhook.id = UUID().uuidString
        webhook.name = name
        webhook.url = url
        webhook.secret = secret
        webhook.events = events
        webhook.isActive = isActive
        webhook.retryAttempts = retryAttempts
        webhook.timeout = timeout
        webhook.createdAt = Date()
        webhook.updatedAt = Date()
        
        try await saveContext()
        return webhook
    }
    
    func updateWebhook(_ config: WebhookConfig) async throws -> WebhookConfig {
        config.updatedAt = Date()
        try await saveContext()
        return config
    }
    
    func deleteWebhook(id: String) async throws {
        guard let webhook = try await findWebhookById(id) else {
            throw WebhookError.notFound
        }
        
        persistenceController.container.viewContext.delete(webhook)
        try await saveContext()
    }
    
    func getWebhooks() async throws -> [WebhookConfig] {
        let request: NSFetchRequest<WebhookConfig> = WebhookConfig.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WebhookConfig.createdAt, ascending: false)]
        
        let webhooks = try persistenceController.container.viewContext.fetch(request)
        print("🔍 [Webhook] getWebhooks() returning \(webhooks.count) webhook(s)")
        
        // Check for duplicates and remove them
        let uniqueWebhooks = removeDuplicateWebhooks(webhooks)
        if uniqueWebhooks.count != webhooks.count {
            print("⚠️ [Webhook] Found \(webhooks.count - uniqueWebhooks.count) duplicate webhook(s), removing them")
        }
        
        for (index, webhook) in uniqueWebhooks.enumerated() {
            print("📋 [Webhook] \(index + 1). ID: \(webhook.id ?? "nil"), Name: \(webhook.name ?? "nil"), URL: \(webhook.url ?? "nil")")
        }
        
        return uniqueWebhooks
    }
    
    private func removeDuplicateWebhooks(_ webhooks: [WebhookConfig]) -> [WebhookConfig] {
        var seenIds = Set<String>()
        var uniqueWebhooks: [WebhookConfig] = []
        
        for webhook in webhooks {
            if let id = webhook.id, !seenIds.contains(id) {
                seenIds.insert(id)
                uniqueWebhooks.append(webhook)
            } else {
                print("🗑️ [Webhook] Removing duplicate webhook with ID: \(webhook.id ?? "nil")")
                // Delete the duplicate from Core Data
                persistenceController.container.viewContext.delete(webhook)
            }
        }
        
        // Save context if we removed duplicates
        if uniqueWebhooks.count != webhooks.count {
            Task {
                try? await saveContext()
            }
        }
        
        return uniqueWebhooks
    }
    
    func triggerWebhook(event: WebhookEvent, data: Any) async {
        print("🔗 [Webhook] Triggering webhook for event: \(event.rawValue)")
        
        let webhooks = try? await findActiveWebhooks(for: event)
        guard let webhooks = webhooks else { 
            print("❌ [Webhook] Failed to find active webhooks for event: \(event.rawValue)")
            return 
        }
        
        print("📡 [Webhook] Found \(webhooks.count) active webhook(s) for event: \(event.rawValue)")
        
        for webhook in webhooks {
            print("🚀 [Webhook] Delivering to webhook: \(webhook.name ?? "Unnamed") (\(webhook.url ?? "No URL"))")
            await deliverWebhook(webhook: webhook, event: event, data: data)
        }
    }
    
    // MARK: - Private Methods
    
    private func deliverWebhook(webhook: WebhookConfig, event: WebhookEvent, data: Any) async {
        print("📦 [Webhook] Creating payload for webhook: \(webhook.name ?? "Unnamed")")
        let payload = createWebhookPayload(event: event, data: data)
        print("📄 [Webhook] Payload created (\(payload.count) characters)")
        
        let delivery = try? await createDelivery(webhookId: webhook.id ?? "", event: event, payload: payload)
        
        guard let delivery = delivery else { 
            print("❌ [Webhook] Failed to create delivery record for webhook: \(webhook.name ?? "Unnamed")")
            return 
        }
        
        print("💾 [Webhook] Delivery record created with ID: \(delivery.id ?? "Unknown")")
        
        Task {
            await self.performDelivery(delivery: delivery, webhook: webhook)
        }
    }
    
    private func performDelivery(delivery: WebhookDelivery, webhook: WebhookConfig) async {
        print("🌐 [Webhook] Performing delivery to: \(webhook.url ?? "Unknown URL")")
        
        do {
            let request = try createWebhookRequest(webhook: webhook, payload: delivery.payload ?? "")
            print("📤 [Webhook] Sending HTTP request...")
            let response = try await networkClient.performRequest(request)
            
            print("📥 [Webhook] Received response with status code: \(response.statusCode)")
            
            if response.statusCode >= 200 && response.statusCode < 300 {
                delivery.status = "delivered"
                delivery.responseCode = Int32(response.statusCode)
                print("✅ [Webhook] Delivery successful! Status: \(response.statusCode)")
            } else {
                print("⚠️ [Webhook] HTTP error: \(response.statusCode)")
                throw WebhookDeliveryError.httpError(response.statusCode)
            }
        } catch {
            delivery.attempts += 1
            delivery.lastAttemptAt = Date()
            
            print("❌ [Webhook] Delivery failed (attempt \(delivery.attempts)/\(webhook.retryAttempts)): \(error.localizedDescription)")
            
            if delivery.attempts < webhook.retryAttempts {
                delivery.status = "retrying"
                delivery.nextRetryAt = calculateNextRetry(attempt: Int(delivery.attempts))
                print("🔄 [Webhook] Will retry at: \(delivery.nextRetryAt?.description ?? "Unknown")")
            } else {
                delivery.status = "failed"
                print("💀 [Webhook] Max retry attempts reached. Delivery failed permanently.")
            }
        }
        
        do {
            try await saveContext()
            print("💾 [Webhook] Delivery status saved to database")
        } catch {
            print("❌ [Webhook] Failed to save delivery status: \(error.localizedDescription)")
        }
    }
    
    private func createWebhookRequest(webhook: WebhookConfig, payload: String) throws -> URLRequest {
        guard let url = URL(string: webhook.url ?? "") else {
            print("❌ [Webhook] Invalid URL: \(webhook.url ?? "nil")")
            throw WebhookDeliveryError.invalidURL
        }
        
        print("🔗 [Webhook] Creating request for URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("EnhancedTimeTracker/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = TimeInterval(webhook.timeout) / 1000.0
        
        print("⏱️ [Webhook] Request timeout: \(request.timeoutInterval) seconds")
        
        // Add HMAC signature if secret is provided
        if let secret = webhook.secret, !secret.isEmpty {
            let signature = try createHMACSignature(payload: payload, secret: secret)
            request.setValue(signature, forHTTPHeaderField: "X-Webhook-Signature")
            print("🔐 [Webhook] HMAC signature added")
        } else {
            print("🔓 [Webhook] No HMAC signature (no secret provided)")
        }
        
        request.httpBody = payload.data(using: .utf8)
        print("📦 [Webhook] Request body size: \(request.httpBody?.count ?? 0) bytes")
        
        return request
    }
    
    private func createHMACSignature(payload: String, secret: String) throws -> String {
        guard let keyData = secret.data(using: .utf8) else {
            throw WebhookDeliveryError.invalidSecret
        }
        
        let key = SymmetricKey(data: keyData)
        let payloadData = payload.data(using: .utf8) ?? Data()
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: key)
        return "sha256=" + Data(signature).map { String(format: "%02hhx", $0) }.joined()
    }
    
    private func createWebhookPayload(event: WebhookEvent, data: Any) -> String {
        print("🔧 [Webhook] Creating payload for event: \(event.rawValue)")
        let serializableData = convertToSerializableData(data)
        
        let payload: [String: Any] = [
            "event": event.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "data": serializableData
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            print("✅ [Webhook] Payload JSON serialization successful")
            return jsonString
        } catch {
            print("❌ [Webhook] JSON serialization failed: \(error.localizedDescription)")
            return "{}"
        }
    }
    
    private func convertToSerializableData(_ data: Any) -> Any {
        if let timeEntry = data as? TimeEntry {
            print("🔄 [Webhook] Converting TimeEntry to serializable format")
            print("📋 [Webhook] TimeEntry ID: \(timeEntry.id ?? "Unknown")")
            print("📋 [Webhook] Project: \(timeEntry.project?.name ?? "Unknown")")
            print("📋 [Webhook] Client: \(timeEntry.client?.name ?? "Unknown")")
            
            let clientData: [String: Any] = [
                "id": timeEntry.client?.id ?? "",
                "name": timeEntry.client?.name ?? "",
                "hourlyRate": timeEntry.client?.hourlyRate ?? 0.0
            ]
            
            // Calculate total time spent on this project
            let totalTime = calculateTotalTimeForProject(projectId: timeEntry.project?.id ?? "")
            let totalTimeInHours = Double(totalTime) / 60.0
            
            let projectData: [String: Any] = [
                "id": timeEntry.project?.id ?? "",
                "name": timeEntry.project?.name ?? "",
                "description": timeEntry.project?.projectDescription ?? "",
                "hourlyRate": timeEntry.project?.hourlyRate ?? 0.0,
                "totalTime": totalTime,
                "totalTimeInHours": totalTimeInHours
            ]
            
            // Calculate the effective hourly rate (project rate takes precedence over client rate)
            let effectiveHourlyRate = (timeEntry.project?.hourlyRate ?? 0.0) > 0.0 ? 
                (timeEntry.project?.hourlyRate ?? 0.0) : 
                (timeEntry.client?.hourlyRate ?? 0.0)
            
            // Calculate earnings for this time entry
            let durationInHours = Double(timeEntry.duration) / 60.0
            let earnings = durationInHours * effectiveHourlyRate
            
            // Calculate monthly totals
            let monthlyTotals = calculateMonthlyTotals()
            
            let timeEntryData: [String: Any] = [
                "id": timeEntry.id ?? "",
                "description": timeEntry.entryDescription ?? "",
                "startTime": formatDate(timeEntry.startTime),
                "endTime": formatDate(timeEntry.endTime),
                "duration": timeEntry.duration,
                "durationInHours": durationInHours,
                "isRunning": timeEntry.isRunning,
                "isManual": timeEntry.isManual,
                "createdAt": formatDate(timeEntry.createdAt),
                "updatedAt": formatDate(timeEntry.updatedAt),
                "hourlyRate": effectiveHourlyRate,
                "earnings": earnings,
                "totalHoursThisMonth": monthlyTotals.totalHours,
                "totallyEarnedThisMonth": monthlyTotals.totalEarnings,
                "client": clientData,
                "project": projectData
            ]
            
            print("💰 [Webhook] Effective hourly rate: \(effectiveHourlyRate), Earnings: \(earnings)")
            print("⏱️ [Webhook] Total time on project: \(totalTime) minutes (\(totalTimeInHours) hours)")
            print("📅 [Webhook] Monthly totals: \(monthlyTotals.totalHours) hours, $\(monthlyTotals.totalEarnings) earnings")
            print("✅ [Webhook] TimeEntry conversion completed")
            return timeEntryData
        } else if let project = data as? Project {
            print("🔄 [Webhook] Converting Project to serializable format")
            print("📋 [Webhook] Project ID: \(project.id ?? "Unknown")")
            print("📋 [Webhook] Project Name: \(project.name ?? "Unknown")")
            print("📋 [Webhook] Client: \(project.client?.name ?? "Unknown")")
            
            let clientData: [String: Any] = [
                "id": project.client?.id ?? "",
                "name": project.client?.name ?? "",
                "hourlyRate": project.client?.hourlyRate ?? 0.0
            ]
            
            let projectData: [String: Any] = [
                "id": project.id ?? "",
                "name": project.name ?? "",
                "description": project.projectDescription ?? "",
                "hourlyRate": project.hourlyRate,
                "isActive": project.isActive,
                "createdAt": formatDate(project.createdAt),
                "updatedAt": formatDate(project.updatedAt),
                "client": clientData
            ]
            
            print("✅ [Webhook] Project conversion completed")
            return projectData
        } else if let projectUpdateData = data as? ProjectUpdateData {
            print("🔄 [Webhook] Converting ProjectUpdateData to serializable format")
            print("📋 [Webhook] Project ID: \(projectUpdateData.project.id ?? "Unknown")")
            print("📋 [Webhook] Project Name: \(projectUpdateData.project.name ?? "Unknown")")
            
            let clientData: [String: Any] = [
                "id": projectUpdateData.project.client?.id ?? "",
                "name": projectUpdateData.project.client?.name ?? "",
                "hourlyRate": projectUpdateData.project.client?.hourlyRate ?? 0.0
            ]
            
            let oldValues: [String: Any] = [
                "name": projectUpdateData.oldName,
                "description": projectUpdateData.oldDescription,
                "hourlyRate": projectUpdateData.oldHourlyRate
            ]
            
            let newValues: [String: Any] = [
                "name": projectUpdateData.project.name ?? "",
                "description": projectUpdateData.project.projectDescription ?? "",
                "hourlyRate": projectUpdateData.project.hourlyRate
            ]
            
            let projectUpdatePayload: [String: Any] = [
                "id": projectUpdateData.project.id ?? "",
                "isActive": projectUpdateData.project.isActive,
                "createdAt": formatDate(projectUpdateData.project.createdAt),
                "updatedAt": formatDate(projectUpdateData.project.updatedAt),
                "client": clientData,
                "oldValues": oldValues,
                "newValues": newValues
            ]
            
            print("✅ [Webhook] ProjectUpdateData conversion completed")
            return projectUpdatePayload
        } else if let client = data as? Client {
            print("🔄 [Webhook] Converting Client to serializable format")
            print("📋 [Webhook] Client ID: \(client.id ?? "Unknown")")
            print("📋 [Webhook] Client Name: \(client.name ?? "Unknown")")
            
            let clientData: [String: Any] = [
                "id": client.id ?? "",
                "name": client.name ?? "",
                "hourlyRate": client.hourlyRate,
                "color": client.color ?? "",
                "isActive": client.isActive,
                "createdAt": formatDate(client.createdAt),
                "updatedAt": formatDate(client.updatedAt)
            ]
            
            print("✅ [Webhook] Client conversion completed")
            return clientData
        } else if let clientUpdateData = data as? ClientUpdateData {
            print("🔄 [Webhook] Converting ClientUpdateData to serializable format")
            print("📋 [Webhook] Client ID: \(clientUpdateData.client.id ?? "Unknown")")
            print("📋 [Webhook] Client Name: \(clientUpdateData.client.name ?? "Unknown")")
            
            let oldValues: [String: Any] = [
                "name": clientUpdateData.oldName,
                "hourlyRate": clientUpdateData.oldHourlyRate,
                "color": clientUpdateData.oldColor
            ]
            
            let newValues: [String: Any] = [
                "name": clientUpdateData.client.name ?? "",
                "hourlyRate": clientUpdateData.client.hourlyRate,
                "color": clientUpdateData.client.color ?? ""
            ]
            
            let clientUpdatePayload: [String: Any] = [
                "id": clientUpdateData.client.id ?? "",
                "isActive": clientUpdateData.client.isActive,
                "createdAt": formatDate(clientUpdateData.client.createdAt),
                "updatedAt": formatDate(clientUpdateData.client.updatedAt),
                "oldValues": oldValues,
                "newValues": newValues
            ]
            
            print("✅ [Webhook] ClientUpdateData conversion completed")
            return clientUpdatePayload
        }
        
        print("⚠️ [Webhook] Unknown data type, returning as-is: \(type(of: data))")
        // For other data types, return as-is
        return data
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
    
    private func calculateNextRetry(attempt: Int) -> Date {
        let delay = pow(2.0, Double(attempt)) * 60 // Exponential backoff in minutes
        return Date().addingTimeInterval(delay * 60)
    }
    
    private func findActiveWebhooks(for event: WebhookEvent) async throws -> [WebhookConfig] {
        print("🔍 [Webhook] Searching for active webhooks for event: \(event.rawValue)")
        let request: NSFetchRequest<WebhookConfig> = WebhookConfig.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND events CONTAINS %@", event.rawValue)
        
        let webhooks = try persistenceController.container.viewContext.fetch(request)
        print("🔍 [Webhook] Found \(webhooks.count) active webhook(s) for event: \(event.rawValue)")
        
        for webhook in webhooks {
            print("📋 [Webhook] - \(webhook.name ?? "Unnamed"): \(webhook.url ?? "No URL")")
        }
        
        return webhooks
    }
    
    private func findWebhookById(_ id: String) async throws -> WebhookConfig? {
        let request: NSFetchRequest<WebhookConfig> = WebhookConfig.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        return try persistenceController.container.viewContext.fetch(request).first
    }
    
    private func createDelivery(webhookId: String, event: WebhookEvent, payload: String) async throws -> WebhookDelivery {
        print("📝 [Webhook] Creating delivery record for webhook ID: \(webhookId)")
        let context = persistenceController.container.viewContext
        
        let delivery = WebhookDelivery(context: context)
        delivery.id = UUID().uuidString
        delivery.webhook = try await findWebhookById(webhookId)
        delivery.event = event.rawValue
        delivery.payload = payload
        delivery.status = "pending"
        delivery.attempts = 0
        delivery.createdAt = Date()
        
        print("📝 [Webhook] Delivery record created with ID: \(delivery.id ?? "Unknown")")
        
        try await saveContext()
        print("💾 [Webhook] Delivery record saved to database")
        return delivery
    }
    
    private func saveContext() async throws {
        let context = persistenceController.container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
    
    private func calculateTotalTimeForProject(projectId: String) -> Int32 {
        guard !projectId.isEmpty else { return 0 }
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        request.predicate = NSPredicate(format: "project.id == %@", projectId)
        
        do {
            let timeEntries = try context.fetch(request)
            let totalTime = timeEntries.reduce(0) { $0 + $1.duration }
            print("📊 [Webhook] Calculated total time for project \(projectId): \(totalTime) minutes")
            return totalTime
        } catch {
            print("❌ [Webhook] Failed to calculate total time for project \(projectId): \(error.localizedDescription)")
            return 0
        }
    }
    
    private func calculateMonthlyTotals() -> (totalHours: Double, totalEarnings: Double) {
        let context = persistenceController.container.viewContext
        let calendar = Calendar.current
        let now = Date()
        
        // Get the start and end of current month
        guard let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end else {
            print("❌ [Webhook] Failed to calculate month boundaries")
            return (0.0, 0.0)
        }
        
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        request.predicate = NSPredicate(format: "startTime >= %@ AND startTime < %@", startOfMonth as NSDate, endOfMonth as NSDate)
        
        do {
            let timeEntries = try context.fetch(request)
            var totalMinutes: Int32 = 0
            var totalEarnings: Double = 0.0
            
            for entry in timeEntries {
                totalMinutes += entry.duration
                
                // Calculate earnings for this entry
                let effectiveHourlyRate = (entry.project?.hourlyRate ?? 0.0) > 0.0 ? 
                    (entry.project?.hourlyRate ?? 0.0) : 
                    (entry.client?.hourlyRate ?? 0.0)
                
                let durationInHours = Double(entry.duration) / 60.0
                totalEarnings += durationInHours * effectiveHourlyRate
            }
            
            let totalHours = Double(totalMinutes) / 60.0
            print("📊 [Webhook] Calculated monthly totals: \(totalHours) hours, $\(totalEarnings) earnings")
            return (totalHours, totalEarnings)
        } catch {
            print("❌ [Webhook] Failed to calculate monthly totals: \(error.localizedDescription)")
            return (0.0, 0.0)
        }
    }
}

// MARK: - Supporting Types

enum WebhookEvent: String, CaseIterable {
    case timeEntryCreated = "time_entry_created"
    case timeEntryUpdated = "time_entry_updated"
    case timeEntryDeleted = "time_entry_deleted"
    case timeEntryStarted = "time_entry_started"
    case timeEntryStopped = "time_entry_stopped"
    case projectCreated = "project_created"
    case projectUpdated = "project_updated"
    case clientCreated = "client_created"
    case clientUpdated = "client_updated"
    case invoiceCreated = "on_invoice_created"
}

enum WebhookError: Error, LocalizedError {
    case notFound
    case invalidURL
    case invalidSecret
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Webhook not found"
        case .invalidURL:
            return "Invalid webhook URL"
        case .invalidSecret:
            return "Invalid webhook secret"
        }
    }
}

enum WebhookDeliveryError: Error, LocalizedError {
    case invalidURL
    case httpError(Int)
    case networkError(Error)
    case invalidSecret
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid webhook URL"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidSecret:
            return "Invalid webhook secret"
        }
    }
}

// MARK: - Network Client

class NetworkClient {
    private let session = URLSession.shared
    
    func performRequest(_ request: URLRequest) async throws -> HTTPURLResponse {
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebhookDeliveryError.networkError(URLError(.badServerResponse))
        }
        
        return httpResponse
    }
}

// MARK: - Supporting Data Structures

struct ProjectUpdateData {
    let project: Project
    let oldName: String
    let oldDescription: String
    let oldHourlyRate: Double
}

struct ClientUpdateData {
    let client: Client
    let oldName: String
    let oldHourlyRate: Double
    let oldColor: String
}
