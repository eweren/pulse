import SwiftUI
import CoreData

struct ClientManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var clientService = ClientService()
    @State private var clients: [Client] = []
    @State private var showingAddClient = false
    @State private var showingEditClient: Client?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var searchText = ""
    
    var filteredClients: [Client] {
        if searchText.isEmpty {
            return clients
        } else {
            return clients.filter { client in
                (client.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern Header
            headerView
            
            // Search Bar
            searchBarView
            
            // Content
            if clients.isEmpty {
                emptyStateView
            } else {
                clientsGridView
            }
        }
        .padding(24)
        .onAppear {
            Task {
                await loadClients()
            }
        }
        .sheet(isPresented: $showingAddClient) {
            AddClientView { client in
                Task {
                    await loadClients()
                }
            }
        }
        .sheet(item: $showingEditClient) { client in
            EditClientView(client: client) { _ in
                Task {
                    await loadClients()
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clients")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(clients.count) client\(clients.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showingAddClient = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                    Text("Add Client")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.bottom, 24)
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("Search clients...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 15))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.bottom, 20)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No clients yet")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Add your first client to start tracking time")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Client") {
                showingAddClient = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var clientsGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredClients) { client in
                    ModernClientCard(
                        client: client,
                        onEdit: { showingEditClient = client },
                        onDelete: {
                            Task {
                                await deleteClient(client)
                            }
                        }
                    )
                }
            }
            .padding(.top, 8)
        }
    }
    
    private func loadClients() async {
        do {
            let fetchedClients = try await clientService.getClients(context: viewContext)
            await MainActor.run {
                self.clients = fetchedClients
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteClient(_ client: Client) async {
        do {
            try await clientService.deleteClient(id: client.id ?? "", context: viewContext)
            await loadClients()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct ModernClientCard: View {
    let client: Client
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with color indicator and actions
            HStack {
                // Color indicator
                Circle()
                    .fill(Color(hex: client.color ?? "#007AFF") ?? .blue)
                    .frame(width: 12, height: 12)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
            
            // Client info
            VStack(alignment: .leading, spacing: 8) {
                Text(client.name ?? "Unknown Client")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "eurosign.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    
                    Text("€\(client.hourlyRate, specifier: "%.2f")/hour")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isHovered ? Color.accentColor.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(isHovered ? 0.1 : 0.05),
                    radius: isHovered ? 8 : 4,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ClientRowView: View {
    let client: Client
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: client.color ?? "#007AFF") ?? .blue)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name ?? "Unknown Client")
                    .font(.headline)
                
                Text("€\(client.hourlyRate, specifier: "%.2f")/hour")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
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
        .padding(.vertical, 4)
    }
}

struct AddClientView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var hourlyRate = 0.0
    @State private var selectedColor = "#007AFF"
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onSave: (Client) -> Void
    
    private let colors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#FF2D92", "#5AC8FA", "#FFCC00"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Add client")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Invisible spacer to center the title
                Color.clear
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
            
            // Form Content
            VStack(spacing: 24) {
                // Name Field
                VStack(spacing: 12) {
                    Text("NAME")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    TextField("Enter client name", text: $name)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                
                // Hourly Rate Field
                VStack(spacing: 12) {
                    Text("HOURLY RATE")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    HStack(spacing: 4) {
                        Text("€")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.primary)
                        
                        TextField("0,00", value: $hourlyRate, format: .number.precision(.fractionLength(2)))
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.primary)
                            .textFieldStyle(PlainTextFieldStyle())
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Color Selection
                VStack(spacing: 16) {
                    Text("COLOR")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color) ?? .blue)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedColor == color ? Color.primary : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                                .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedColor)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedColor = color
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer with buttons
            HStack(spacing: 12) {
                Button("Delete") {
                    // No delete action for new client
                }
                .buttonStyle(ModernDeleteButtonStyle())
                .disabled(true)
                .opacity(0.3)
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await saveClient()
                    }
                }
                .buttonStyle(ModernSaveButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 300, height: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveClient() async {
        do {
            let context = PersistenceController.shared.container.viewContext
            let clientService = ClientService()
            let client = try await clientService.createClient(
                name: name,
                hourlyRate: hourlyRate,
                color: selectedColor,
                context: context
            )
            
            await MainActor.run {
                onSave(client)
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

struct EditClientView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var hourlyRate: Double
    @State private var selectedColor: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteAlert = false
    
    let client: Client
    let onSave: (Client) -> Void
    
    private let colors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#FF2D92", "#5AC8FA", "#FFCC00"]
    
    init(client: Client, onSave: @escaping (Client) -> Void) {
        self.client = client
        self.onSave = onSave
        self._name = State(initialValue: client.name ?? "")
        self._hourlyRate = State(initialValue: client.hourlyRate)
        self._selectedColor = State(initialValue: client.color ?? "#007AFF")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Edit client")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Invisible spacer to center the title
                Color.clear
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
            
            // Form Content
            VStack(spacing: 24) {
                // Name Field
                VStack(spacing: 12) {
                    Text("NAME")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    TextField("Enter client name", text: $name)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                
                // Hourly Rate Field
                VStack(spacing: 12) {
                    Text("HOURLY RATE")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    HStack(spacing: 4) {
                        Text("€")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.primary)
                        
                        TextField("0,00", value: $hourlyRate, format: .number.precision(.fractionLength(2)))
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.primary)
                            .textFieldStyle(PlainTextFieldStyle())
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Color Selection
                VStack(spacing: 16) {
                    Text("COLOR")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color) ?? .blue)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedColor == color ? Color.primary : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                                .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedColor)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedColor = color
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer with buttons
            HStack(spacing: 12) {
                Button("Delete") {
                    showingDeleteAlert = true
                }
                .buttonStyle(ModernDeleteButtonStyle())
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await saveClient()
                    }
                }
                .buttonStyle(ModernSaveButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 300, height: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Delete Client", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteClient()
                }
            }
        } message: {
            Text("Are you sure you want to delete this client? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveClient() async {
        do {
            client.name = name
            client.hourlyRate = hourlyRate
            client.color = selectedColor
            
            let context = PersistenceController.shared.container.viewContext
            let clientService = ClientService()
            let updatedClient = try await clientService.updateClient(client, context: context)
            
            await MainActor.run {
                onSave(updatedClient)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteClient() async {
        do {
            let context = PersistenceController.shared.container.viewContext
            let clientService = ClientService()
            try await clientService.deleteClient(id: client.id ?? "", context: context)
            
            await MainActor.run {
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

// MARK: - Modern UI Components

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ClientManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
