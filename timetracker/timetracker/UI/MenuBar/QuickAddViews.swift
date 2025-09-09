import SwiftUI
import CoreData

struct QuickAddClientView: View {
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
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            // Form Content
            VStack(spacing: 24) {
                // Name Field
                VStack(spacing: 12) {
                    Text("NAME")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
            .padding(.bottom, 16)
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

struct QuickAddProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var hourlyRate = 0.0
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let client: Client
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
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            // Form Content
            VStack(spacing: 24) {
                // Client Display
                VStack(spacing: 12) {
                    Text("CLIENT")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(client.name ?? "Unknown Client")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                
                // Name Field
                VStack(spacing: 12) {
                    Text("NAME")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("Enter project description (optional)", text: $description, axis: .vertical)
                        .font(.system(size: 14, weight: .light))
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 300, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveProject() async {
        do {
            let context = PersistenceController.shared.container.viewContext
            let projectService = ProjectService()
            let project = try await projectService.createProject(
                name: name,
                description: description.isEmpty ? nil : description,
                clientId: client.id ?? "",
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


#Preview {
    let context = PersistenceController.preview.container.viewContext
    let client = Client(context: context)
    client.name = "Sample Client"
    
    return QuickAddProjectView(client: client) { _ in }
        .environment(\.managedObjectContext, context)
}
