import SwiftUI
import CoreData

struct ProjectManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var projectService = ProjectService()
    @StateObject private var clientService = ClientService()
    @State private var projects: [Project] = []
    @State private var clients: [Client] = []
    @State private var selectedClient: Client?
    @State private var showingAddProject = false
    @State private var showingEditProject: Project?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            clientFilter
            projectsList
        }
        .padding()
        .onAppear {
            Task {
                await loadData()
            }
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView { project in
                Task {
                    await loadProjects()
                }
            }
        }
        .sheet(item: $showingEditProject) { project in
            EditProjectView(project: project) { _ in
                Task {
                    await loadProjects()
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
            Text("Projects")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("Add Project") {
                showingAddProject = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var clientFilter: some View {
        HStack {
            Text("Filter by client:")
                .font(.subheadline)
            
            Picker("Client", selection: $selectedClient) {
                Text("All Clients").tag(nil as Client?)
                ForEach(clients) { client in
                    Text(client.name ?? "Unknown").tag(client as Client?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: 200)
        }
    }
    
    private var projectsList: some View {
        List {
            ForEach(filteredProjects) { project in
                ProjectRowView(project: project) {
                    showingEditProject = project
                } onDelete: {
                    Task {
                        await deleteProject(project)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var filteredProjects: [Project] {
        if let selectedClient = selectedClient {
            return projects.filter { $0.client?.id == selectedClient.id }
        }
        return projects
    }
    
    private func loadData() async {
        await loadClients()
        await loadProjects()
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
    
    private func loadProjects() async {
        do {
            let fetchedProjects = try await projectService.getProjects(clientId: nil, context: viewContext)
            await MainActor.run {
                self.projects = fetchedProjects
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteProject(_ project: Project) async {
        do {
            try await projectService.deleteProject(id: project.id ?? "", context: viewContext)
            await loadProjects()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name ?? "Unknown Project")
                    .font(.headline)
                
                if let description = project.projectDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(project.client?.name ?? "Unknown Client")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if project.hourlyRate > 0 {
                        Text("• $\(project.hourlyRate, specifier: "%.2f")/hour")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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

struct AddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var selectedClientId = ""
    @State private var hourlyRate = 0.0
    @State private var clients: [Client] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onSave: (Project) -> Void
    
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
                
                Text("Add project")
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
                // Client Selection
                VStack(spacing: 12) {
                    Text("CLIENT")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    Picker("Client", selection: $selectedClientId) {
                        Text("Select a client").tag("")
                        ForEach(clients) { client in
                            if let clientId = client.id, !clientId.isEmpty {
                                Text(client.name ?? "Unknown").tag(clientId)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedClientId) { _, newClientId in
                        // Prefill hourly rate when client is selected
                        if let selectedClient = clients.first(where: { $0.id == newClientId }) {
                            hourlyRate = selectedClient.hourlyRate
                        }
                    }
                }
                
                // Name Field
                VStack(spacing: 12) {
                    Text("NAME")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    TextField("Enter project name", text: $name)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                
                // Description Field
                VStack(spacing: 12) {
                    Text("DESCRIPTION")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    TextField("Enter project description (optional)", text: $description, axis: .vertical)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(2...4)
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
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer with buttons
            HStack(spacing: 12) {
                Button("Delete") {
                    // No delete action for new project
                }
                .buttonStyle(ModernDeleteButtonStyle())
                .disabled(true)
                .opacity(0.3)
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await saveProject()
                    }
                }
                .buttonStyle(ModernSaveButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedClientId.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 300, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                await loadClients()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadClients() async {
        do {
            let context = PersistenceController.shared.container.viewContext
            let clientService = ClientService()
            let fetchedClients = try await clientService.getClients(context: context)
            await MainActor.run {
                self.clients = fetchedClients
                if let firstClient = fetchedClients.first {
                    self.selectedClientId = firstClient.id ?? ""
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func saveProject() async {
        do {
            let context = PersistenceController.shared.container.viewContext
            let projectService = ProjectService()
            let project = try await projectService.createProject(
                name: name,
                description: description.isEmpty ? nil : description,
                clientId: selectedClientId,
                hourlyRate: hourlyRate > 0 ? hourlyRate : nil,
                context: context
            )
            
            await MainActor.run {
                onSave(project)
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

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var selectedClientId: String
    @State private var hourlyRate: Double
    @State private var clients: [Client] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteAlert = false
    
    let project: Project
    let onSave: (Project) -> Void
    
    init(project: Project, onSave: @escaping (Project) -> Void) {
        self.project = project
        self.onSave = onSave
        self._name = State(initialValue: project.name ?? "")
        self._description = State(initialValue: project.projectDescription ?? "")
        self._selectedClientId = State(initialValue: project.client?.id ?? "")
        self._hourlyRate = State(initialValue: project.hourlyRate)
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
                
                Text("Edit project")
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
                // Client Selection
                VStack(spacing: 12) {
                    Text("CLIENT")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    Picker("Client", selection: $selectedClientId) {
                        Text("Select a client").tag("")
                        ForEach(clients) { client in
                            if let clientId = client.id, !clientId.isEmpty {
                                Text(client.name ?? "Unknown").tag(clientId)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Name Field
                VStack(spacing: 12) {
                    Text("NAME")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    TextField("Enter project name", text: $name)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                
                // Description Field
                VStack(spacing: 12) {
                    Text("DESCRIPTION")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                    
                    TextField("Enter project description (optional)", text: $description, axis: .vertical)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(2...4)
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
                        await saveProject()
                    }
                }
                .buttonStyle(ModernSaveButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedClientId.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(width: 300, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                await loadClients()
            }
        }
        .alert("Delete Project", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteProject()
                }
            }
        } message: {
            Text("Are you sure you want to delete this project? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadClients() async {
        do {
            let context = PersistenceController.shared.container.viewContext
            let clientService = ClientService()
            let fetchedClients = try await clientService.getClients(context: context)
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
    
    private func saveProject() async {
        do {
            project.name = name
            project.projectDescription = description.isEmpty ? nil : description
            project.hourlyRate = hourlyRate
            
            let context = PersistenceController.shared.container.viewContext
            let projectService = ProjectService()
            let updatedProject = try await projectService.updateProject(project, context: context)
            
            await MainActor.run {
                onSave(updatedProject)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteProject() async {
        do {
            let context = PersistenceController.shared.container.viewContext
            let projectService = ProjectService()
            try await projectService.deleteProject(id: project.id ?? "", context: context)
            
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

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
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
    }
}

struct ModernPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Modern Button Styles

struct ModernSaveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ModernDeleteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.3))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ProjectManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
