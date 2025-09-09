import SwiftUI
import CoreData

struct ArchivedItemsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var clientService = ClientService()
    @StateObject private var projectService = ProjectService()
    
    @State private var archivedClients: [Client] = []
    @State private var archivedProjects: [Project] = []
    @State private var selectedTab = 0
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Tab Picker
            tabPickerView
            
            // Content
            contentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            Task {
                await loadArchivedItems()
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Archived Items")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Manage archived clients and projects")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Refresh") {
                Task {
                    await loadArchivedItems()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    private var tabPickerView: some View {
        Picker("Content", selection: $selectedTab) {
            Text("Clients (\(archivedClients.count))").tag(0)
            Text("Projects (\(archivedProjects.count))").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading archived items...")
            Spacer()
        } else {
            switch selectedTab {
            case 0:
                archivedClientsView
            case 1:
                archivedProjectsView
            default:
                EmptyView()
            }
        }
    }
    
    private var archivedClientsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if archivedClients.isEmpty {
                    emptyStateView(
                        icon: "person.crop.circle",
                        title: "No Archived Clients",
                        message: "There are no archived clients to display."
                    )
                } else {
                    ForEach(archivedClients) { client in
                        ArchivedClientCard(
                            client: client,
                            onRestore: {
                                Task {
                                    await restoreClient(client)
                                }
                            },
                            onPermanentDelete: {
                                Task {
                                    await permanentlyDeleteClient(client)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }
    
    private var archivedProjectsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if archivedProjects.isEmpty {
                    emptyStateView(
                        icon: "folder",
                        title: "No Archived Projects",
                        message: "There are no archived projects to display."
                    )
                } else {
                    ForEach(archivedProjects) { project in
                        ArchivedProjectCard(
                            project: project,
                            onRestore: {
                                Task {
                                    await restoreProject(project)
                                }
                            },
                            onPermanentDelete: {
                                Task {
                                    await permanentlyDeleteProject(project)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }
    
    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private func loadArchivedItems() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let clients = try await clientService.getArchivedClients(context: viewContext)
            let projects = try await projectService.getArchivedProjects(context: viewContext)
            
            await MainActor.run {
                self.archivedClients = clients
                self.archivedProjects = projects
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showingError = true
                self.isLoading = false
            }
        }
    }
    
    private func restoreClient(_ client: Client) async {
        do {
            try await clientService.restoreClient(id: client.id ?? "", context: viewContext)
            await loadArchivedItems()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func permanentlyDeleteClient(_ client: Client) async {
        do {
            try await clientService.permanentlyDeleteClient(id: client.id ?? "", context: viewContext)
            await loadArchivedItems()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func restoreProject(_ project: Project) async {
        do {
            try await projectService.restoreProject(id: project.id ?? "", context: viewContext)
            await loadArchivedItems()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func permanentlyDeleteProject(_ project: Project) async {
        do {
            try await projectService.permanentlyDeleteProject(id: project.id ?? "", context: viewContext)
            await loadArchivedItems()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct ArchivedClientCard: View {
    let client: Client
    let onRestore: () -> Void
    let onPermanentDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Client icon
            Circle()
                .fill(Color(hex: client.color ?? "#007AFF") ?? .blue)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                )
            
            // Client info
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name ?? "Unknown Client")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack {
                    Text("$\(client.hourlyRate, specifier: "%.2f")/hr")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let updatedAt = client.updatedAt {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Archived \(updatedAt, formatter: shortDateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 6) {
                Button("Restore") {
                    onRestore()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Delete") {
                    showingDeleteAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .alert("Permanently Delete Client", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                onPermanentDelete()
            }
        } message: {
            Text("Are you sure you want to permanently delete '\(client.name ?? "this client")'? This action cannot be undone.")
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}

struct ArchivedProjectCard: View {
    let project: Project
    let onRestore: () -> Void
    let onPermanentDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Project icon
            Circle()
                .fill(Color(NSColor.controlAccentColor))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "folder.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                )
            
            // Project info
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name ?? "Unknown Project")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack {
                    Text(project.client?.name ?? "Unknown Client")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let updatedAt = project.updatedAt {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Archived \(updatedAt, formatter: shortDateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let description = project.projectDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 6) {
                Button("Restore") {
                    onRestore()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Delete") {
                    showingDeleteAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .alert("Permanently Delete Project", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                onPermanentDelete()
            }
        } message: {
            Text("Are you sure you want to permanently delete '\(project.name ?? "this project")'? This action cannot be undone.")
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
}


#Preview {
    ArchivedItemsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
