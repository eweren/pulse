import SwiftUI

struct ExpandableButton: View {
    let icon: String
    let text: String
    let action: () -> Void
    let color: Color
    let textSize: CGFloat
    
    @State private var isHovered = false
    
    init(icon: String, text: String, color: Color = .primary, textSize: CGFloat = 11, action: @escaping () -> Void) {
        self.icon = icon
        self.text = text
        self.color = color
        self.textSize = textSize
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if !isHovered {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 16, height: 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
                
                if isHovered {
                    Text(text)
                        .font(.system(size: textSize, weight: .medium))
                        .foregroundColor(.primary)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, isHovered ? 8 : 6)
            .padding(.vertical, 6)
            .frame(height: 28) // Fixed height to prevent layout shifts
            .background(
                RoundedRectangle(cornerRadius: isHovered ? 16 : 20)
                    .fill(isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.8) : Color.clear)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            // Set cursor to pointing hand on hover
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        ExpandableButton(icon: "plus", text: "Add", action: {})
        ExpandableButton(icon: "archivebox", text: "Archive", action: {})
        ExpandableButton(icon: "questionmark", text: "Help", action: {})
        ExpandableButton(icon: "xmark", text: "Quit", action: {})
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
