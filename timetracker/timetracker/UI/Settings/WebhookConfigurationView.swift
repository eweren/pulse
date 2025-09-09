import SwiftUI
import CoreData

struct WebhookConfigurationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var webhookService = WebhookService()
    @State private var webhooks: [WebhookConfig] = []
    @State private var showingAddWebhook = false
    @State private var showingEditWebhook: WebhookConfig?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            webhooksList
        }
        .padding()
        .onAppear {
            Task {
                await loadWebhooks()
            }
        }
        .sheet(isPresented: $showingAddWebhook) {
            AddWebhookView { webhook in
                Task {
                    await loadWebhooks()
                }
            }
        }
        .sheet(item: $showingEditWebhook) { webhook in
            EditWebhookView(webhook: webhook) { _ in
                Task {
                    await loadWebhooks()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Webhook Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Webhook") {
                    showingAddWebhook = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            Text("Configure webhooks to send time entry events to external systems. All webhook deliveries are optional and user-controlled.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var webhooksList: some View {
        List {
            ForEach(webhooks, id: \.id) { webhook in
                WebhookRowView(webhook: webhook) {
                    showingEditWebhook = webhook
                } onDelete: {
                    Task {
                        await deleteWebhook(webhook)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func loadWebhooks() async {
        do {
            let fetchedWebhooks = try await webhookService.getWebhooks()
            await MainActor.run {
                print("🔄 [Webhook UI] Loading \(fetchedWebhooks.count) webhook(s) into UI")
                for (index, webhook) in fetchedWebhooks.enumerated() {
                    print("📋 [Webhook UI] \(index + 1). ID: \(webhook.id ?? "nil"), Name: \(webhook.name ?? "nil")")
                }
                self.webhooks = fetchedWebhooks
                print("✅ [Webhook UI] Webhooks loaded into UI state")
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteWebhook(_ webhook: WebhookConfig) async {
        do {
            try await webhookService.deleteWebhook(id: webhook.id ?? "")
            await loadWebhooks()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct WebhookRowView: View {
    let webhook: WebhookConfig
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(webhook.name ?? "Unknown Webhook")
                        .font(.headline)
                    
                    Text(webhook.url ?? "No URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(webhook.isActive ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text(webhook.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Edit") {
                        onEdit()
                    }
                     .buttonStyle(PlainButtonStyle())
                    
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.red)
                }
            }
            
            if let events = webhook.events, !events.isEmpty {
                Text("Events: \(events)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddWebhookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var secret = ""
    @State private var selectedEvents: Set<WebhookEvent> = [.timeEntryCreated]
    @State private var isActive = true
    @State private var retryAttempts = 3
    @State private var timeout = 30000
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onSave: (WebhookConfig) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Webhook")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.headline)
                        TextField("Webhook name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(.headline)
                        TextField("https://example.com/webhook", text: $url)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secret (optional)")
                            .font(.headline)
                        SecureField("Webhook secret for HMAC signature", text: $secret)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Events")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(WebhookEvent.allCases, id: \.self) { event in
                                HStack {
                                    Image(systemName: selectedEvents.contains(event) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedEvents.contains(event) ? .blue : .secondary)
                                    Text(event.rawValue)
                                        .font(.caption)
                                    Spacer()
                                }
                                .onTapGesture {
                                    if selectedEvents.contains(event) {
                                        selectedEvents.remove(event)
                                    } else {
                                        selectedEvents.insert(event)
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Retry Attempts")
                            .font(.headline)
                        TextField("3", value: $retryAttempts, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timeout (milliseconds)")
                            .font(.headline)
                        TextField("30000", value: $timeout, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Toggle("Active", isOn: $isActive)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await saveWebhook()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedEvents.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 600)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveWebhook() async {
        do {
            let webhookService = WebhookService()
            let eventsString = selectedEvents.map { $0.rawValue }.joined(separator: ",")
            
            let webhook = try await webhookService.createWebhook(
                name: name,
                url: url,
                secret: secret.isEmpty ? nil : secret,
                events: eventsString,
                isActive: isActive,
                retryAttempts: Int32(retryAttempts),
                timeout: Int32(timeout)
            )
            
            await MainActor.run {
                onSave(webhook)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct EditWebhookView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var url: String
    @State private var secret: String
    @State private var selectedEvents: Set<WebhookEvent>
    @State private var isActive: Bool
    @State private var retryAttempts: Int
    @State private var timeout: Int
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let webhook: WebhookConfig
    let onSave: (WebhookConfig) -> Void
    
    init(webhook: WebhookConfig, onSave: @escaping (WebhookConfig) -> Void) {
        self.webhook = webhook
        self.onSave = onSave
        self._name = State(initialValue: webhook.name ?? "")
        self._url = State(initialValue: webhook.url ?? "")
        self._secret = State(initialValue: webhook.secret ?? "")
        self._isActive = State(initialValue: webhook.isActive)
        self._retryAttempts = State(initialValue: Int(webhook.retryAttempts))
        self._timeout = State(initialValue: Int(webhook.timeout))
        
        // Parse events
        let eventsString = webhook.events ?? ""
        let eventsArray = eventsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        self._selectedEvents = State(initialValue: Set(eventsArray.compactMap { WebhookEvent(rawValue: $0) }))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Webhook")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.headline)
                        TextField("Webhook name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(.headline)
                        TextField("https://example.com/webhook", text: $url)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secret (optional)")
                            .font(.headline)
                        SecureField("Webhook secret for HMAC signature", text: $secret)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Events")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(WebhookEvent.allCases, id: \.self) { event in
                                HStack {
                                    Image(systemName: selectedEvents.contains(event) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedEvents.contains(event) ? .blue : .secondary)
                                    Text(event.rawValue)
                                        .font(.caption)
                                    Spacer()
                                }
                                .onTapGesture {
                                    if selectedEvents.contains(event) {
                                        selectedEvents.remove(event)
                                    } else {
                                        selectedEvents.insert(event)
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Retry Attempts")
                            .font(.headline)
                        TextField("3", value: $retryAttempts, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timeout (milliseconds)")
                            .font(.headline)
                        TextField("30000", value: $timeout, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Toggle("Active", isOn: $isActive)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await saveWebhook()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedEvents.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 600)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveWebhook() async {
        do {
            webhook.name = name
            webhook.url = url
            webhook.secret = secret.isEmpty ? nil : secret
            webhook.events = selectedEvents.map { $0.rawValue }.joined(separator: ",")
            webhook.isActive = isActive
            webhook.retryAttempts = Int32(retryAttempts)
            webhook.timeout = Int32(timeout)
            
            let webhookService = WebhookService()
            let updatedWebhook = try await webhookService.updateWebhook(webhook)
            
            await MainActor.run {
                onSave(updatedWebhook)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    WebhookConfigurationView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
