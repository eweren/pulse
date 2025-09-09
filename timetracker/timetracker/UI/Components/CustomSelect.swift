import SwiftUI

struct CustomSelect<Item: Hashable>: View {
    let items: [Item]
    let itemTitle: (Item) -> String
    @Binding var selectedItem: Item
    let onSelectionChange: (Item) -> Void
    
    @State private var isExpanded = false
    @State private var isHovered = false
    
    init(
        items: [Item],
        selectedItem: Binding<Item>,
        itemTitle: @escaping (Item) -> String = { "\($0)" },
        onSelectionChange: @escaping (Item) -> Void = { _ in }
    ) {
        self.items = items
        self._selectedItem = selectedItem
        self.itemTitle = itemTitle
        self.onSelectionChange = onSelectionChange
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main select button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    
                    Text(itemTitle(selectedItem))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.6) : Color(NSColor.controlBackgroundColor).opacity(0.3))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            
            // Dropdown options - normal layout flow
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Button(action: {
                            selectedItem = item
                            onSelectionChange(item)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }) {
                            HStack {
                                Text(itemTitle(item))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(item == selectedItem ? .primary : .secondary)
                                
                                Spacer()
                                
                                if item == selectedItem {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(NSColor.controlAccentColor))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Rectangle()
                                    .fill(item == selectedItem ? Color(NSColor.controlAccentColor).opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        
                        // Divider between items (except after the last one)
                        if index < items.count - 1 {
                            Divider()
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .onTapGesture {
            // Close dropdown when tapping outside
            if isExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CustomSelect(
            items: ["This week", "This month", "Last month", "This year", "All time"],
            selectedItem: .constant("This month")
        )
        
        CustomSelect(
            items: ["Option 1", "Option 2", "Option 3"],
            selectedItem: .constant("Option 2")
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
