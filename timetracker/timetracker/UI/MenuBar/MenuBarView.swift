import SwiftUI
import CoreData

struct MenuBarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var timerService: TimerService
    @StateObject private var timeEntryService = TimeEntryService()
    @StateObject private var webhookService = WebhookService()
    @State private var showingManualEntry = false
    @State private var showingSettings = false
    @State private var showingAddClient = false
    @State private var showingAddProject: Client?
    @State private var showingInvoiceAlert = false
    @State private var clients: [Client] = []
    @State private var selectedTimePeriod = "This month"
    @State private var earningsUpdateTimer: Timer?
    @State private var earningsUpdateTrigger: Bool = false
    @State private var clientSectionRefreshTrigger: Bool = false
    @State private var hasActiveInvoiceWebhooks: Bool = false
    @State private var pendingTimerStart: PendingTimerStart?
    @State private var pendingTimerTaskDescription: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Main content with clients and projects
            ScrollView {
                LazyVStack(spacing: 0) {
                    if clients.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(Array(clients.enumerated()), id: \.element.id) { index, client in
                            ClientSectionView(
                                client: client,
                                currentTimer: timerService.currentTimer,
                                onStartTimer: { project in
                                    pendingTimerTaskDescription = "Working on \(project.name ?? "project")"
                                    pendingTimerStart = PendingTimerStart(project: project, client: client)
                                },
                                onStopTimer: {
                                    Task {
                                        await stopCurrentTimer()
                                    }
                                },
                                onAddProject: {
                                    showingAddProject = client
                                },
                                timePeriod: selectedTimePeriod
                            )
                            .id("\(client.id ?? "")-\(clientSectionRefreshTrigger)")
                            
                            // Add divider between client sections (but not after the last one)
                            if index < clients.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 600)
            
            Divider()
            
            // Earnings footer
            earningsView
            
            Divider()
            
            // Action buttons
            actionButtonsView
        }
        .frame(width: 350, height: 600)
        .onAppear {
            Task {
                await loadData()
                await checkForActiveInvoiceWebhooks()
            }
            startEarningsUpdateTimer()
            timerService.setViewVisible(true)
        }
        .onDisappear {
            stopEarningsUpdateTimer()
            timerService.setViewVisible(false)
        }
        .onChange(of: timerService.currentTimer) {
            // Start/stop earnings update timer when timer state changes
            if timerService.currentTimer != nil {
                startEarningsUpdateTimer()
            } else {
                stopEarningsUpdateTimer()
            }
        }
        .onChange(of: selectedTimePeriod) {
            Task {
                await loadData()
            }
            clientSectionRefreshTrigger.toggle() // Force refresh of all client sections
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView {
                Task {
                    await loadData()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: showingSettings) { _, newValue in
            // When settings view is dismissed, check for webhook changes
            if !newValue {
                Task {
                    await checkForActiveInvoiceWebhooks()
                }
            }
        }
        .sheet(isPresented: $showingAddClient) {
            QuickAddClientView { _ in
                Task {
                    await loadClients()
                }
            }
        }
        .sheet(item: $showingAddProject) { client in
            QuickAddProjectView(client: client) { _ in
                Task {
                    await loadClients()
                    clientSectionRefreshTrigger.toggle()
                }
            }
        }
        .sheet(item: $pendingTimerStart) { pending in
            StartTimerTaskSheet(
                projectName: pending.project.name ?? "Project",
                taskDescription: $pendingTimerTaskDescription,
                onStart: {
                    let description = pendingTimerTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    let project = pending.project
                    let client = pending.client
                    pendingTimerStart = nil
                    Task {
                        await startTimer(for: project, client: client, description: description)
                    }
                },
                onCancel: {
                    pendingTimerStart = nil
                }
            )
        }
        .confirmationDialog("Create Invoices", isPresented: $showingInvoiceAlert) {
            Button("Create invoices for last month") {
                Task {
                    await createInvoicesForMonth(offset: -1)
                }
            }
            
            Button("Create invoices for this month") {
                Task {
                    await createInvoicesForMonth(offset: 0)
                }
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose which month to create invoices for")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            // Current timer display
            if let currentTimer = timerService.currentTimer {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentTimer.project?.name ?? "Unbekanntes Projekt")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let desc = currentTimer.entryDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Text(timerService.formattedElapsedTimeWithSeconds)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await stopCurrentTimer()
                        }
                    }) {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 12)
            }
            
            
            // Original header
            HStack {
                // Custom time period picker
                CustomSelect(
                    items: ["This week", "Last week", "This month", "Last month", "This year", "All time"],
                    selectedItem: $selectedTimePeriod
                ).zIndex(90)
                
                Spacer()
                
                HStack(spacing: 8) {
                    ExpandableButton(
                        icon: "person.badge.plus",
                        text: "Add Client",
                        action: {
                            showingAddClient = true
                        }
                    )
                    
                    ExpandableButton(
                        icon: "xmark",
                        text: "Quit",
                        color: .secondary,
                        action: {
                            NSApplication.shared.terminate(nil)
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .padding(.top, 16)
    }
    
    private var earningsView: some View {
        HStack {
            Text("Earned \(selectedTimePeriod.lowercased())")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("€\(totalEarnings, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                ExpandableButton(
                    icon: "arrow.down.circle",
                    text: "Export CSV",
                    color: .secondary,
                    textSize: 11,
                    action: {
                        Task {
                            await exportTimeEntriesToCSV()
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 8) {
            ExpandableButton(
                icon: "plus",
                text: "Add Time Entry",
                action: {
                    showingManualEntry = true
                }
            )
            
            ExpandableButton(
                icon: "gearshape",
                text: "Settings",
                action: {
                    showingSettings = true
                }
            )
            
            if hasActiveInvoiceWebhooks {
                ExpandableButton(
                    icon: "doc.text",
                    text: "Create Invoices",
                    action: {
                        showingInvoiceAlert = true
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var totalEarnings: Double {
        // Use the trigger to force recalculation when timer is running
        _ = earningsUpdateTrigger
        
        // Calculate total earnings for selected time period
        let calendar = Calendar.current
        let now = Date()
        let (startDate, endDate) = getDateRange(for: selectedTimePeriod, calendar: calendar, now: now)
        
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        if let endDate = endDate {
            request.predicate = NSPredicate(
                format: "startTime >= %@ AND startTime < %@ AND isRunning == NO",
                startDate as NSDate,
                endDate as NSDate
            )
        } else {
            // For "All time", no upper bound
            request.predicate = NSPredicate(
                format: "startTime >= %@ AND isRunning == NO",
                startDate as NSDate
            )
        }
        
        do {
            let entries = try viewContext.fetch(request)
            
            // Calculate earnings from completed entries
            let completedEarnings = entries.reduce(0) { total, entry in
                let duration = Double(entry.duration) / 60.0 // Convert minutes to hours
                let projectRate = entry.project?.hourlyRate ?? 0.0
                let clientRate = entry.client?.hourlyRate ?? 0.0
                let hourlyRate = projectRate > 0 ? projectRate : clientRate
                let earnings = duration * hourlyRate
                
                return total + earnings
            }
            
            // Add earnings from current running timer (only if it falls within the selected time period)
            var runningEarnings: Double = 0.0
            if let currentTimer = timerService.currentTimer,
               let timerStartTime = currentTimer.startTime {
                // Check if the timer started within the selected time period
                let isInRange: Bool
                if let endDate = endDate {
                    isInRange = timerStartTime >= startDate && timerStartTime < endDate
                } else {
                    isInRange = timerStartTime >= startDate
                }
                if isInRange {
                    let elapsedTime = timerService.elapsedTime
                    let duration = elapsedTime / 3600.0 // Convert seconds to hours (3600 seconds = 1 hour)
                    let projectRate = currentTimer.project?.hourlyRate ?? 0.0
                    let clientRate = currentTimer.client?.hourlyRate ?? 0.0
                    let hourlyRate = projectRate > 0 ? projectRate : clientRate
                    runningEarnings = duration * hourlyRate
                }
            }
            
            return completedEarnings + runningEarnings
        } catch {
            print("Error fetching time entries: \(error)")
            return 0.0
        }
    }
    
    private func loadData() async {
        await loadClients()
    }
    
    private func checkForActiveInvoiceWebhooks() async {
        do {
            let webhooks = try await webhookService.getWebhooks()
            let activeInvoiceWebhooks = webhooks.filter { webhook in
                webhook.isActive && 
                (webhook.events?.contains("on_invoice_created") == true)
            }
            
            await MainActor.run {
                self.hasActiveInvoiceWebhooks = !activeInvoiceWebhooks.isEmpty
            }
        } catch {
            print("Error checking for active invoice webhooks: \(error)")
            await MainActor.run {
                self.hasActiveInvoiceWebhooks = false
            }
        }
    }
    
    private func loadClients() async {
        let request: NSFetchRequest<Client> = Client.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Client.name, ascending: true)]
        
        do {
            let fetchedClients = try viewContext.fetch(request)
            await MainActor.run {
                self.clients = fetchedClients
            }
        } catch {
            print("Error loading clients: \(error)")
        }
    }
    
    
    private func startTimer(for project: Project, client: Client, description: String) async {
        let descriptionToUse = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Working on \(project.name ?? "project")"
            : description
        do {
            let entry = try await timeEntryService.startTimer(
                clientId: client.id ?? "",
                projectId: project.id ?? "",
                description: descriptionToUse
            )
            await MainActor.run {
                timerService.startTimer(for: entry)
                // Force refresh of all client sections to update button states
                clientSectionRefreshTrigger.toggle()
            }
        } catch {
            print("Error starting timer: \(error)")
        }
    }
    
    private func stopCurrentTimer() async {
        guard let timer = timerService.currentTimer else { return }
        
        do {
            _ = try await timeEntryService.stopTimer(entryId: timer.id ?? "")
            await MainActor.run {
                timerService.stopTimer()
                // Force refresh of all client sections to update button states
                clientSectionRefreshTrigger.toggle()
            }
        } catch {
            print("Error stopping timer: \(error)")
        }
    }
    
    private func startEarningsUpdateTimer() {
        // Only start timer if there's a running timer
        guard timerService.currentTimer != nil else { return }
        
        stopEarningsUpdateTimer() // Stop any existing timer
        
        earningsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Force view update by toggling a state variable
            // This will cause the totalEarnings computed property to recalculate
            DispatchQueue.main.async {
                self.earningsUpdateTrigger.toggle()
            }
        }
    }
    
    private func stopEarningsUpdateTimer() {
        earningsUpdateTimer?.invalidate()
        earningsUpdateTimer = nil
    }
    
    private func exportTimeEntriesToCSV() async {
        do {
            let calendar = Calendar.current
            let now = Date()
            
            // Get date range based on selected time period
            let (startDate, endDate) = getDateRange(for: selectedTimePeriod, calendar: calendar, now: now)
            
            // Fetch time entries for the selected period
            let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
            if let endDate = endDate {
                request.predicate = NSPredicate(
                    format: "startTime >= %@ AND startTime < %@",
                    startDate as NSDate,
                    endDate as NSDate
                )
            } else {
                // For "All time", no upper bound
                request.predicate = NSPredicate(
                    format: "startTime >= %@",
                    startDate as NSDate
                )
            }
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TimeEntry.startTime, ascending: true)]
            
            let timeEntries = try viewContext.fetch(request)
            
            // Create CSV content
            var csvContent = "Date,Client,Project,Description,Start Time,End Time,Duration (minutes),Duration (hours),Hourly Rate,Earnings\n"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short
            
            for entry in timeEntries {
                let clientName = entry.client?.name ?? "Unknown Client"
                let projectName = entry.project?.name ?? "Unknown Project"
                let description = entry.description ?? ""
                let startTime = entry.startTime ?? Date()
                let endTime = entry.endTime ?? Date()
                let duration = Double(entry.duration)
                let durationHours = duration / 60.0
                
                // Calculate hourly rate (project rate takes precedence over client rate)
                let projectRate = entry.project?.hourlyRate ?? 0.0
                let clientRate = entry.client?.hourlyRate ?? 0.0
                let hourlyRate = projectRate > 0 ? projectRate : clientRate
                let earnings = durationHours * hourlyRate
                
                // Format dates and times
                let dateString = dateFormatter.string(from: startTime)
                let startTimeString = timeFormatter.string(from: startTime)
                let endTimeString = timeFormatter.string(from: endTime)
                
                // Escape CSV values (handle commas and quotes)
                let escapedClientName = escapeCSVValue(clientName)
                let escapedProjectName = escapeCSVValue(projectName)
                let escapedDescription = escapeCSVValue(description)
                
                csvContent += "\(dateString),\(escapedClientName),\(escapedProjectName),\(escapedDescription),\(startTimeString),\(endTimeString),\(Int(duration)),\(String(format: "%.2f", durationHours)),\(String(format: "%.2f", hourlyRate)),\(String(format: "%.2f", earnings))\n"
            }
            
            // Show save dialog
            await MainActor.run {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.commaSeparatedText]
                savePanel.nameFieldStringValue = "time_entries_\(selectedTimePeriod.lowercased().replacingOccurrences(of: " ", with: "_"))_\(dateFormatter.string(from: now).replacingOccurrences(of: "/", with: "-")).csv"
                savePanel.title = "Export Time Entries"
                savePanel.message = "Choose where to save the CSV file"
                
                savePanel.begin { response in
                    if response == .OK, let url = savePanel.url {
                        do {
                            try csvContent.write(to: url, atomically: true, encoding: .utf8)
                            print("CSV exported successfully to: \(url.path)")
                        } catch {
                            print("Error writing CSV file: \(error)")
                        }
                    }
                }
            }
            
        } catch {
            print("Error exporting time entries: \(error)")
        }
    }
    
    private func getDateRange(for timePeriod: String, calendar: Calendar, now: Date) -> (Date, Date?) {
        switch timePeriod {
        case "This week":
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            return (startOfWeek, endOfWeek)
            
        case "Last week":
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            let startOfLastWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.start ?? now
            let endOfLastWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.end ?? now
            return (startOfLastWeek, endOfLastWeek)
            
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
            // Get the end of the year by adding 1 year and subtracting 1 second
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) ?? now
            return (startOfYear, endOfYear)
            
        case "All time":
            // Return nil for endDate to indicate no upper bound
            return (Date.distantPast, nil)
            
        default:
            // Default to this month
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return (startOfMonth, endOfMonth)
        }
    }
    
    private func escapeCSVValue(_ value: String) -> String {
        // If the value contains comma, quote, or newline, wrap it in quotes and escape internal quotes
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedValue)\""
        }
        return value
    }
    
    private func createInvoicesForMonth(offset: Int) async {
        do {
            let calendar = Calendar.current
            let now = Date()
            let targetDate = calendar.date(byAdding: .month, value: offset, to: now) ?? now
            
            // Get the start and end of the target month
            let startOfMonth = calendar.dateInterval(of: .month, for: targetDate)?.start ?? targetDate
            let endOfMonth = calendar.dateInterval(of: .month, for: targetDate)?.end ?? targetDate
            
            // Fetch all time entries for the month
            let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
            request.predicate = NSPredicate(format: "startTime >= %@ AND startTime < %@", startOfMonth as NSDate, endOfMonth as NSDate)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TimeEntry.startTime, ascending: true)]
            
            let timeEntries = try viewContext.fetch(request)
            
            // Group time entries by project
            var projectTimeEntries: [String: [TimeEntry]] = [:]
            for entry in timeEntries {
                guard let projectId = entry.project?.id else { continue }
                if projectTimeEntries[projectId] == nil {
                    projectTimeEntries[projectId] = []
                }
                projectTimeEntries[projectId]?.append(entry)
            }
            
            // Create invoice data for each project
            for (projectId, entries) in projectTimeEntries {
                guard let firstEntry = entries.first,
                      let project = firstEntry.project,
                      let client = project.client else { continue }
                
                // Calculate total time for this project
                let totalMinutes = entries.reduce(into: 0.0) { $0 += Double($1.duration) }
                
                // Only include projects with more than 1 minute tracked
                guard totalMinutes > 1.0 else { continue }
                
                let totalHours = totalMinutes / 60.0
                let roundedHours = round(totalHours * 4) / 4  // Round to nearest 0.25
                
                // Create invoice data
                let invoiceData: [String: Any] = [
                    "invoiceId": UUID().uuidString,
                    "createdAt": Date().timeIntervalSince1970,
                    "month": offset == 0 ? "this_month" : "last_month",
                    "client": [
                        "id": client.id ?? "",
                        "name": client.name ?? "",
                        "hourlyRate": client.hourlyRate
                    ],
                    "project": [
                        "id": project.id ?? "",
                        "name": project.name ?? "",
                        "description": project.projectDescription ?? "",
                        "hourlyRate": project.hourlyRate
                    ],
                    "timeEntries": entries.map { entry in
                        [
                            "id": entry.id ?? "",
                            "description": entry.description ?? "",
                            "startTime": entry.startTime?.timeIntervalSince1970 ?? 0,
                            "endTime": entry.endTime?.timeIntervalSince1970 ?? 0,
                            "duration": Double(entry.duration)
                        ]
                    },
                    "summary": [
                        "totalTimeMinutes": totalMinutes,
                        "totalTimeHours": totalHours,
                        "totalTimeHoursRounded": roundedHours,
                        "totalEntries": entries.count,
                        "startDate": startOfMonth.timeIntervalSince1970,
                        "endDate": endOfMonth.timeIntervalSince1970
                    ]
                ]
                
                // Trigger webhook
                try await webhookService.triggerWebhook(
                    event: .invoiceCreated,
                    data: invoiceData
                )
            }
            
            print("Created invoices for \(projectTimeEntries.count) projects")
            
        } catch {
            print("Error creating invoices: \(error)")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Icon with background circle
            ZStack {
                Circle()
                    .fill(Color(NSColor.controlAccentColor).opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.2.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color(NSColor.controlAccentColor))
            }
            
            // Text content
            VStack(spacing: 8) {
                Text("No clients yet")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Add your first client to start tracking time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Call to action button
            Button("Add Client") {
                showingAddClient = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
}

// MARK: - Start timer task prompt

struct PendingTimerStart: Identifiable {
    let project: Project
    let client: Client
    var id: String { project.id ?? UUID().uuidString }
}

struct StartTimerTaskSheet: View {
    let projectName: String
    @Binding var taskDescription: String
    let onStart: () -> Void
    let onCancel: () -> Void
    
    private var canStart: Bool {
        !taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What are you working on?")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Project: \(projectName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Task description", text: $taskDescription)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("Start") {
                    onStart()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStart)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}

#Preview {
    MenuBarView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
