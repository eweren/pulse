import SwiftUI
import CoreData
import UserNotifications
import AppKit

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var autoStartService: AutoStartService
    @State private var selectedTab = 0
    
    var body: some View {
        HStack(spacing: 0) {
            // Modern Sidebar
            sidebarView
            
            // Main Content Area
            contentView
        }
        .frame(width: 800, height: 600)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Manage your time tracking preferences")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close Settings")
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
            
            // Navigation Items
            VStack(spacing: 4) {
                NavigationItem(
                    icon: "person.2.fill",
                    title: "Clients",
                    subtitle: "Manage client information",
                    isSelected: selectedTab == 0
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 0
                    }
                }
                
                NavigationItem(
                    icon: "folder.fill",
                    title: "Projects",
                    subtitle: "Organize your projects",
                    isSelected: selectedTab == 1
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 1
                    }
                }
                
                NavigationItem(
                    icon: "link.circle.fill",
                    title: "Webhooks",
                    subtitle: "Configure integrations",
                    isSelected: selectedTab == 2
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 2
                    }
                }
                
                NavigationItem(
                    icon: "archivebox.fill",
                    title: "Archived Items",
                    subtitle: "Manage archived clients and projects",
                    isSelected: selectedTab == 3
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 3
                    }
                }
                
                NavigationItem(
                    icon: "gear.circle.fill",
                    title: "General",
                    subtitle: "App preferences",
                    isSelected: selectedTab == 4
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 4
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 1, x: 1, y: 0)
        )
    }
    
    private var contentView: some View {
        Group {
            switch selectedTab {
            case 0:
                ClientManagementView()
            case 1:
                ProjectManagementView()
            case 2:
                WebhookConfigurationView()
            case 3:
                ArchivedItemsView()
            case 4:
                GeneralSettingsView()
                    .environmentObject(autoStartService)
            default:
                ClientManagementView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

struct NavigationItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isSelected ? .primary : .primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GeneralSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var autoStartService: AutoStartService
    @State private var showingResetAlert = false
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderAfterHours") private var reminderAfterHours = 4.0
    @AppStorage("idleDetectionEnabled") private var idleDetectionEnabled = false
    @AppStorage("idleTimeoutMinutes") private var idleTimeoutMinutes = 15
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("General Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("About Enhanced Time Tracker")
                        .font(.headline)
                    
                    Text("Version 0.0.13")
                        .foregroundColor(.secondary)
                    
                    Text("A privacy-first time tracking application that keeps all your data local while providing optional webhook integrations.")
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    Text("Startup")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Launch at login", isOn: $autoStartService.isAutoStartEnabled)
                                .toggleStyle(SwitchToggleStyle())
                            
                            Spacer()
                        }
                        
                        Text("Automatically start the time tracker when you log in to your Mac")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Divider()
                    
                    Text("Keyboard shortcut")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default: Control-Command-T to show the menu from anywhere. Requires Accessibility permission in System Settings → Privacy & Security → Accessibility.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open Accessibility Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    
                    Divider()
                    
                    Text("Timer reminder")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Notify when timer has been running for …", isOn: $reminderEnabled)
                            .toggleStyle(SwitchToggleStyle())
                            .onChange(of: reminderEnabled) { _, newValue in
                                if newValue {
                                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                                }
                            }
                        if reminderEnabled {
                            Picker("Duration", selection: $reminderAfterHours) {
                                Text("2 hours").tag(2.0)
                                Text("4 hours").tag(4.0)
                                Text("6 hours").tag(6.0)
                                Text("8 hours").tag(8.0)
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 120)
                        }
                        Text("Send a notification if the timer has been running for this long (e.g. to avoid forgetting to stop it).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Divider()
                    
                    Text("Idle detection")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Stop timer when idle for …", isOn: $idleDetectionEnabled)
                            .toggleStyle(SwitchToggleStyle())
                        if idleDetectionEnabled {
                            Picker("Idle timeout", selection: $idleTimeoutMinutes) {
                                Text("5 minutes").tag(5)
                                Text("10 minutes").tag(10)
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 160)
                        }
                        Text("If no keyboard or mouse activity for this long, the running timer will be stopped automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                
                Divider()
                
                Text("Privacy")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All data stored locally on your Mac")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No cloud synchronization")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("No telemetry or usage tracking")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Webhooks are optional and user-controlled")
                    }
                }
                .font(.caption)
                
                Divider()
                
                Text("Data Management")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reset all time tracking data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Reset All Time Entries") {
                        showingResetAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .tint(.red)
                }
                
                Spacer(minLength: 20)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Reset All Time Entries", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset All", role: .destructive) {
                resetAllTimeEntries()
            }
        } message: {
            Text("This will permanently delete all time entries. This action cannot be undone. Are you sure you want to continue?")
        }
    }
    
    private func resetAllTimeEntries() {
        let request: NSFetchRequest<TimeEntry> = TimeEntry.fetchRequest()
        
        do {
            let allTimeEntries = try viewContext.fetch(request)
            for entry in allTimeEntries {
                viewContext.delete(entry)
            }
            try viewContext.save()
        } catch {
            print("Error resetting time entries: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
