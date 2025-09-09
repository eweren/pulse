import Foundation
import AppKit
import SwiftUI
import Combine

class StatusBarManager: NSObject, ObservableObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var timerService: TimerService?
    private var menuBarView: NSHostingView<MenuBarView>?
    private var popover: NSPopover?
    
    override init() {
        super.init()
        setupStatusBar()
    }
    
    func setTimerService(_ timerService: TimerService) {
        self.timerService = timerService
        
        // Observe timer changes and update status bar
        timerService.$statusBarTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                self?.updateStatusBarTitle(title)
            }
            .store(in: &cancellables)
        
        // Observe timer state changes and update icon
        timerService.$currentTimer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarIcon()
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = ""
            // Use dynamic icon based on timer state
            button.image = createCustomStatusBarIcon(isTimerRunning: false) // Start with idle state
            button.image?.isTemplate = true // This makes it adapt to light/dark mode
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }
    }
    
    private func createCustomStatusBarIcon(isTimerRunning: Bool = false) -> NSImage? {
        // Use ICNS files based on timer state
        let icnsName = isTimerRunning ? "statusbar-icon-running" : "statusbar-icon-idle"
        
        // Try with .icns extension first
        if let image = NSImage(named: icnsName) {
            // Ensure the image is properly sized for status bar (16x16)
            image.size = NSSize(width: 16, height: 16)
            return image
        }
        
        // Try without extension
        let nameWithoutExtension = icnsName.replacingOccurrences(of: ".icns", with: "")
        if let image = NSImage(named: nameWithoutExtension) {
            image.size = NSSize(width: 16, height: 16)
            return image
        }
        
        // Fallback to system symbols based on timer state
        let systemSymbolName = isTimerRunning ? "stopwatch.fill" : "stopwatch"
        return NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: "Time Tracker")
    }
    
    private func updateStatusBarIcon() {
        DispatchQueue.main.async {
            let isTimerRunning = self.timerService?.currentTimer != nil
            let newIcon = self.createCustomStatusBarIcon(isTimerRunning: isTimerRunning)
            self.statusItem?.button?.image = newIcon
            self.statusItem?.button?.image?.isTemplate = true
        }
    }
    
    private func updateStatusBarTitle(_ title: String) {
        DispatchQueue.main.async {
            self.statusItem?.button?.title = title
        }
    }
    
    @objc private func statusBarButtonClicked() {
        // Toggle popover visibility
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }
    
    private func showPopover() {
        guard let button = statusItem?.button else { return }
        
        // Close existing popover if any
        if let existingPopover = popover, existingPopover.isShown {
            existingPopover.performClose(nil)
        }
        
        // Create a new popover window
        let newPopover = NSPopover()
        newPopover.contentSize = NSSize(width: 350, height: 400)
        newPopover.behavior = .transient
        newPopover.animates = true
        
        // Create the MenuBarView
        let menuBarView = MenuBarView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(timerService ?? TimerService())
        
        let hostingView = NSHostingView(rootView: menuBarView)
        newPopover.contentViewController = NSViewController()
        newPopover.contentViewController?.view = hostingView
        
        // Set the popover delegate to handle closing
        newPopover.delegate = self
        
        // Store reference to the popover
        self.popover = newPopover
        
        // Show the popover
        newPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    
    deinit {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
    
    // MARK: - NSPopoverDelegate
    
    func popoverDidClose(_ notification: Notification) {
        // Clear the popover reference when it closes
        popover = nil
    }
}
