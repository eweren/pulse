import SwiftUI
import CoreData

struct EditTimeEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let timeEntry: TimeEntry
    @StateObject private var viewModel: EditTimeEntryViewModel
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = true
    
    let onSave: (() -> Void)?
    let onDelete: (() -> Void)?
    
    init(timeEntry: TimeEntry, onSave: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.timeEntry = timeEntry
        self.onSave = onSave
        self.onDelete = onDelete
        _viewModel = StateObject(wrappedValue: EditTimeEntryViewModel(timeEntry: timeEntry))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        formView
                    }
                    .padding(20)
                }
            }
            Divider()
            buttonView
        }
        .frame(width: 350, height: 600)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            Task {
                await viewModel.loadData(context: viewContext)
                await MainActor.run {
                    isLoading = false
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Delete Time Entry", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteEntry()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this time entry? This action cannot be undone.")
        }
    }
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .font(.title2)
                    .foregroundColor(Color(NSColor.controlAccentColor))
                
                Text("Edit Time Entry")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            ExpandableButton(
                icon: "xmark",
                text: "Cancel",
                color: .secondary,
                action: {
                    dismiss()
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var formView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                clientPicker
                projectPicker
            }
            
            // Description Section
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(title: "Description", icon: "text.alignleft")
                descriptionField
            }
            
            // Time Section
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(title: "Time Details", icon: "clock")
                
                VStack(spacing: 16) {
                    DateTimePicker(
                        startDate: $viewModel.startTime,
                        endDate: $viewModel.endTime
                    )
                    
                    durationDisplay
                }
            }
        }
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(NSColor.controlAccentColor))
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    private var clientPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Client", selection: $viewModel.selectedClientId) {
                Text("Select a client").tag("")
                ForEach(viewModel.clients) { client in
                    if let clientId = client.id, !clientId.isEmpty {
                        Text(client.name ?? "Unknown").tag(clientId)
                    }
                }
            }
            .pickerStyle(MenuPickerStyle())
            .disabled(viewModel.clients.isEmpty)
            .onChange(of: viewModel.selectedClientId) { _, newClientId in
                Task {
                    await viewModel.loadProjects(context: viewContext)
                }
            }
        }
    }
    
    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Project", selection: $viewModel.selectedProjectId) {
                Text("Select a project").tag("")
                ForEach(viewModel.projects) { project in
                    if let projectId = project.id, !projectId.isEmpty {
                        Text(project.name ?? "Unknown").tag(projectId)
                    }
                }
            }
            .pickerStyle(MenuPickerStyle())
            .disabled(viewModel.selectedClientId.isEmpty || viewModel.projects.isEmpty)
        }
    }
    
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("What did you work on?", text: $viewModel.description, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    viewModel.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                    Color.clear : 
                                    Color(NSColor.controlAccentColor).opacity(0.5), 
                                    lineWidth: 1
                                )
                        )
                )
        }
    }
    
    private var durationDisplay: some View {
        HStack(spacing: 12) {
            Text("Duration")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(viewModel.formattedDuration)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(NSColor.controlAccentColor))
                .monospacedDigit()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlAccentColor).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.controlAccentColor).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var buttonView: some View {
        HStack(spacing: 12) {
            ExpandableButton(
                icon: "trash",
                text: "Delete",
                color: .red,
                action: {
                    showingDeleteConfirmation = true
                }
            )
            
            Spacer()
            
            if isSaving {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Saving...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                )
            } else {
                ExpandableButton(
                    icon: "checkmark",
                    text: "Save Changes",
                    color: viewModel.isValid ? .primary : .secondary,
                    action: {
                        Task {
                            await saveEntry()
                        }
                    }
                )
                .disabled(!viewModel.isValid || isSaving)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func saveEntry() async {
        await MainActor.run {
            isSaving = true
        }
        
        do {
            let timeEntryService = TimeEntryService()
            
            // Update the time entry with new values
            timeEntry.entryDescription = viewModel.description
            timeEntry.startTime = viewModel.startTime
            timeEntry.endTime = viewModel.endTime
            timeEntry.duration = Int32(viewModel.endTime.timeIntervalSince(viewModel.startTime) / 60)
            
            // Update client and project if changed
            if let newClient = viewModel.clients.first(where: { $0.id == viewModel.selectedClientId }) {
                timeEntry.client = newClient
            }
            if let newProject = viewModel.projects.first(where: { $0.id == viewModel.selectedProjectId }) {
                timeEntry.project = newProject
            }
            
            // Ensure it's not running if it has an end time
            if timeEntry.endTime != nil {
                timeEntry.isRunning = false
            }
            
            _ = try await timeEntryService.updateTimeEntry(timeEntry)
            
            await MainActor.run {
                isSaving = false
                onSave?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteEntry() async {
        await MainActor.run {
            isSaving = true
        }
        
        do {
            let timeEntryService = TimeEntryService()
            try await timeEntryService.deleteTimeEntry(id: timeEntry.id ?? "")
            
            await MainActor.run {
                isSaving = false
                onDelete?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

class EditTimeEntryViewModel: ObservableObject {
    @Published var selectedClientId: String = ""
    @Published var selectedProjectId: String = ""
    @Published var description: String = ""
    @Published var startTime: Date = Date()
    @Published var endTime: Date = Date()
    @Published var clients: [Client] = []
    @Published var projects: [Project] = []
    
    private let timeEntry: TimeEntry
    
    init(timeEntry: TimeEntry) {
        self.timeEntry = timeEntry
        self.description = timeEntry.entryDescription ?? ""
        self.startTime = timeEntry.startTime ?? Date()
        // If endTime is nil (running entry), set it to 1 hour after startTime
        if let endTime = timeEntry.endTime {
            self.endTime = endTime
        } else {
            self.endTime = timeEntry.startTime?.addingTimeInterval(3600) ?? Date().addingTimeInterval(3600)
        }
        self.selectedClientId = timeEntry.client?.id ?? ""
        self.selectedProjectId = timeEntry.project?.id ?? ""
    }
    
    var isValid: Bool {
        !selectedClientId.isEmpty &&
        !selectedProjectId.isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        endTime > startTime
    }
    
    var formattedDuration: String {
        let duration = Int(endTime.timeIntervalSince(startTime) / 60)
        let hours = duration / 60
        let minutes = duration % 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    func loadData(context: NSManagedObjectContext) async {
        await loadClients(context: context)
        await loadProjects(context: context)
    }
    
    private func loadClients(context: NSManagedObjectContext) async {
        let request: NSFetchRequest<Client> = Client.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Client.name, ascending: true)]
        
        do {
            let fetchedClients = try context.fetch(request)
            await MainActor.run {
                self.clients = fetchedClients
            }
        } catch {
            print("Error loading clients: \(error)")
        }
    }
    
    func loadProjects(context: NSManagedObjectContext) async {
        guard !selectedClientId.isEmpty else { 
            await MainActor.run {
                self.projects = []
            }
            return 
        }
        
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        request.predicate = NSPredicate(format: "client.id == %@ AND isActive == YES", selectedClientId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Project.name, ascending: true)]
        
        do {
            let fetchedProjects = try context.fetch(request)
            await MainActor.run {
                self.projects = fetchedProjects
            }
        } catch {
            print("Error loading projects: \(error)")
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let client = Client(context: context)
    client.id = UUID().uuidString
    client.name = "Sample Client"
    client.isActive = true
    
    let project = Project(context: context)
    project.id = UUID().uuidString
    project.name = "Sample Project"
    project.client = client
    project.isActive = true
    
    let timeEntry = TimeEntry(context: context)
    timeEntry.id = UUID().uuidString
    timeEntry.client = client
    timeEntry.project = project
    timeEntry.entryDescription = "Sample work"
    timeEntry.startTime = Date().addingTimeInterval(-3600)
    timeEntry.endTime = Date()
    timeEntry.duration = 60
    
    return EditTimeEntryView(timeEntry: timeEntry)
        .environment(\.managedObjectContext, context)
}

