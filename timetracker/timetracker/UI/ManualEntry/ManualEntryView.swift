import SwiftUI
import CoreData

struct ManualEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = ManualEntryViewModel()
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    let onSave: (() -> Void)?
    
    init(onSave: (() -> Void)? = nil) {
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                VStack(spacing: 20) {
                    formView
                }
                .padding(20)
            }
            Divider()
            buttonView
        }
        .frame(width: 350, height: 600)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            Task {
                await viewModel.loadData(context: viewContext)
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
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.plus")
                    .font(.title2)
                    .foregroundColor(Color(NSColor.controlAccentColor))
                
                Text("Add Time Entry")
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
                    text: "Save Entry",
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
            _ = try await timeEntryService.addManualTimeEntry(
                clientId: viewModel.selectedClientId,
                projectId: viewModel.selectedProjectId,
                description: viewModel.description,
                startTime: viewModel.startTime,
                endTime: viewModel.endTime
            )
            
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
}

class ManualEntryViewModel: ObservableObject {
    @Published var selectedClientId: String = ""
    @Published var selectedProjectId: String = ""
    @Published var description: String = ""
    @Published var startTime: Date = Date()
    @Published var endTime: Date = Date().addingTimeInterval(3600) // 1 hour later
    @Published var clients: [Client] = []
    @Published var projects: [Project] = []
    
    private let timeEntryService = TimeEntryService()
    private let clientService = ClientService()
    private let projectService = ProjectService()
    
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
        if let firstClient = clients.first {
            selectedClientId = firstClient.id ?? ""
            await loadProjects(context: context)
        }
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
                self.selectedProjectId = ""
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
                // Reset selected project and select first one if available
                self.selectedProjectId = ""
                if let firstProject = fetchedProjects.first {
                    self.selectedProjectId = firstProject.id ?? ""
                }
            }
        } catch {
            print("Error loading projects: \(error)")
        }
    }
}

#Preview {
    ManualEntryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
