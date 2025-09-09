import SwiftUI
import CoreData

struct ClientSectionView: View {
    let client: Client
    let currentTimer: TimeEntry?
    let onStartTimer: (Project) -> Void
    let onStopTimer: () -> Void
    let onAddProject: () -> Void
    let timePeriod: String
    
    @State private var projects: [Project] = []
    @State private var showingEditClient = false
    @State private var refreshTrigger = false
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Client header
            clientHeaderView
            
            // Projects list
            if !projects.isEmpty {
                VStack(spacing: 0) {
                    ForEach(projects) { project in
                        SimpleProjectRowView(
                            project: project,
                            currentTimer: currentTimer,
                            onStartTimer: { onStartTimer(project) },
                            onStopTimer: onStopTimer,
                            timePeriod: timePeriod
                        )
                        .id("\(project.id ?? "")-\(timePeriod)")
                    }
                }
            }
        }
        .onAppear {
            loadProjects()
        }
        .onChange(of: refreshTrigger) { _ in
            loadProjects()
        }
        .onChange(of: timePeriod) { _ in
            loadProjects()
            refreshTrigger.toggle() // Force refresh of all child components
        }
        .sheet(isPresented: $showingEditClient) {
            EditClientView(client: client) { _ in
                // Client was updated, refresh if needed
            }
        }
    }
    
    private var clientHeaderView: some View {
        HStack(spacing: 0) {
                ExpandableButton(
                    icon: "plus",
                    text: "Add Project",
                    color: .secondary,
                    action: onAddProject
                )
            
            Text((client.name ?? "Unknown Client").uppercased())
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary).padding(.horizontal, 8)
            
            Spacer()
            
            ExpandableButton(
                icon: "pencil",
                text: "Edit Client",
                color: .secondary,
                action: { showingEditClient = true }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
    
    private func loadProjects() {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        request.predicate = NSPredicate(format: "client.id == %@ AND isActive == YES", client.id ?? "")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Project.name, ascending: true)]
        
        do {
            projects = try client.managedObjectContext?.fetch(request) ?? []
        } catch {
            print("Error loading projects: \(error)")
        }
    }
    
    
    func refreshProjects() {
        refreshTrigger.toggle()
    }
}

struct SimpleProjectRowView: View {
    let project: Project
    let currentTimer: TimeEntry?
    let onStartTimer: () -> Void
    let onStopTimer: () -> Void
    let timePeriod: String
    
    @State private var totalTime: Int32 = 0
    @State private var isCurrentlyRunning = false
    @State private var calculatedEarnings: Double = 0.0
    
    private var clientColor: Color {
        guard let colorString = project.client?.color else {
            return Color.blue // Default color
        }
        
        // Convert hex string to Color
        let hex = colorString.replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            let red = Double((hexNumber & 0xff0000) >> 16) / 255.0
            let green = Double((hexNumber & 0x00ff00) >> 8) / 255.0
            let blue = Double(hexNumber & 0x0000ff) / 255.0
            return Color(red: red, green: green, blue: blue)
        }
        
        return Color.blue // Default color if parsing fails
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Colored circle matching client color
            Circle()
                .fill(clientColor)
                .frame(width: 12, height: 12).padding(.horizontal, 3)
            
            // Project name
            Text(project.name ?? "Unknown Project")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Time and earnings display
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(totalTime))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .monospacedDigit()
                
                if calculatedEarnings > 0 {
                    Text(formatEarnings(calculatedEarnings))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            
            // Play/Pause button
            Button(action: {
                if isCurrentlyRunning {
                    onStopTimer()
                } else {
                    onStartTimer()
                }
            }) {
                Image(systemName: isCurrentlyRunning ? "pause.fill" : "play.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(isCurrentlyRunning ? Color.orange : Color.green)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            isCurrentlyRunning ? 
            Color.blue.opacity(0.1) : 
            Color.clear
        )
        .onAppear {
            loadProjectTime()
            checkIfRunning()
        }
        .onChange(of: timePeriod) { _ in
            loadProjectTime()
        }
        .onChange(of: currentTimer) { newTimer in
            checkIfRunning()
        }
        .onChange(of: currentTimer?.id) { newId in
            checkIfRunning()
        }
        .onChange(of: currentTimer?.project?.id) { newProjectId in
            checkIfRunning()
        }
    }
    
    private func formatTime(_ minutes: Int32) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }
    
    private func formatEarnings(_ earnings: Double) -> String {
        return String(format: "€%.2f", earnings)
    }
    
    private func getDateRange(for timePeriod: String, calendar: Calendar, now: Date) -> (Date, Date) {
        switch timePeriod {
        case "This week":
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            return (startOfWeek, endOfWeek)
            
        case "This month":
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return (startOfMonth, endOfMonth)
            
        case "Last month":
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
            let endOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
            return (startOfLastMonth, endOfLastMonth)
            
        case "This year":
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let endOfYear = calendar.dateInterval(of: .year, for: now)?.end ?? now
            return (startOfYear, endOfYear)
            
        case "All time":
            let distantPast = Date.distantPast
            let distantFuture = Date.distantFuture
            return (distantPast, distantFuture)
            
        default:
            // Default to this month
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return (startOfMonth, endOfMonth)
        }
    }
    
    private func loadProjectTime() {
        let calendar = Calendar.current
        let now = Date()
        
        let (startDate, endDate) = getDateRange(for: timePeriod, calendar: calendar, now: now)
        
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "project.id == %@ AND startTime >= %@ AND startTime < %@",
            project.id ?? "",
            startDate as NSDate,
            endDate as NSDate
        )
        
        do {
            let entries = try project.managedObjectContext?.fetch(request) ?? []
            totalTime = entries.reduce(0) { total, entry in
                if entry.isRunning {
                    // For running entries, calculate current duration
                    let startTime = entry.startTime ?? Date()
                    let currentDuration = Int32(Date().timeIntervalSince(startTime) / 60)
                    return total + currentDuration
                } else {
                    return total + entry.duration
                }
            }
            
            // Calculate earnings based on total time and project hourly rate
            let totalHours = Double(totalTime) / 60.0
            let hourlyRate = project.hourlyRate
            calculatedEarnings = totalHours * hourlyRate
        } catch {
            print("Error loading project time: \(error)")
        }
    }
    
    private func checkIfRunning() {
        let wasRunning = isCurrentlyRunning
        isCurrentlyRunning = currentTimer?.project?.id == project.id
        
        // Force UI update if state changed
        if wasRunning != isCurrentlyRunning {
            DispatchQueue.main.async {
                // This will trigger a view update
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let client = Client(context: context)
    client.id = UUID().uuidString
    client.name = "Sample Client"
    client.hourlyRate = 75.0
    client.color = "#007AFF"
    client.isActive = true
    
    let project = Project(context: context)
    project.id = UUID().uuidString
    project.name = "Sample Project"
    project.client = client
    project.isActive = true
    
    return ClientSectionView(
        client: client,
        currentTimer: nil,
        onStartTimer: { _ in },
        onStopTimer: { },
        onAddProject: { },
        timePeriod: "This month"
    )
    .environment(\.managedObjectContext, context)
}
