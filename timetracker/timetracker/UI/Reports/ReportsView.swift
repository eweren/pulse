import SwiftUI
import CoreData

struct ReportsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimePeriod = "This month"
    @State private var rows: [ClientReportRow] = []
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            periodPicker
            Divider()
            reportTable
            Divider()
            footerView
        }
        .frame(width: 500, height: 480)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            loadReport()
        }
        .onChange(of: selectedTimePeriod) { _, _ in
            loadReport()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reports")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Time and earnings by client for the selected period.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
    
    private var periodPicker: some View {
        HStack {
            Text("Period")
                .font(.subheadline)
                .foregroundColor(.secondary)
            CustomSelect(
                items: PeriodDateRange.periodOptions,
                selectedItem: $selectedTimePeriod
            )
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var reportTable: some View {
        Group {
            if rows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No time entries in this period")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(rows) {
                    TableColumn("Client") { row in
                        Text(row.clientName)
                            .font(.subheadline)
                    }
                    TableColumn("Time") { row in
                        Text(row.formattedTime)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    TableColumn("Earnings") { row in
                        Text(row.formattedEarnings)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }
                .tableStyle(.bordered(alternatesRowBackgrounds: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var footerView: some View {
        HStack {
            let totalTime = rows.reduce(0) { $0 + $1.totalMinutes }
            let totalEarnings = rows.reduce(0.0) { $0 + $1.earnings }
            let hours = totalTime / 60
            let mins = totalTime % 60
            Text("Total: \(String(format: "%02d:%02d", hours, mins)) · €\(totalEarnings, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
        .padding()
    }
    
    private func loadReport() {
        let calendar = Calendar.current
        let now = Date()
        let (startDate, endDate) = PeriodDateRange.getDateRange(for: selectedTimePeriod, calendar: calendar, now: now)
        
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        if let endDate = endDate {
            request.predicate = NSPredicate(
                format: "startTime >= %@ AND startTime < %@ AND isRunning == NO",
                startDate as NSDate,
                endDate as NSDate
            )
        } else {
            request.predicate = NSPredicate(
                format: "startTime >= %@ AND isRunning == NO",
                startDate as NSDate
            )
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TimeEntry.startTime, ascending: true)]
        
        do {
            let entries = try viewContext.fetch(request)
            var byClient: [String: (name: String, minutes: Int, earnings: Double)] = [:]
            for entry in entries {
                guard let client = entry.client, let clientId = client.id else { continue }
                let name = client.name ?? "Unknown Client"
                let minutes = Int(entry.duration)
                let rate = entry.project?.hourlyRate ?? entry.client?.hourlyRate ?? 0
                let earnings = (Double(minutes) / 60.0) * rate
                var existing = byClient[clientId] ?? (name, 0, 0.0)
                existing.minutes += minutes
                existing.earnings += earnings
                byClient[clientId] = existing
            }
            rows = byClient.map { _, v in
                ClientReportRow(
                    clientName: v.name,
                    totalMinutes: v.minutes,
                    earnings: v.earnings
                )
            }
            .sorted { $0.earnings > $1.earnings }
        } catch {
            rows = []
        }
    }
}

struct ClientReportRow: Identifiable {
    let id = UUID()
    let clientName: String
    let totalMinutes: Int
    let earnings: Double
    
    var formattedTime: String {
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }
    
    var formattedEarnings: String {
        String(format: "€%.2f", earnings)
    }
}

#Preview {
    ReportsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
