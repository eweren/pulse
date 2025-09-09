import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "clock")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Enhanced Time Tracker")
                .font(.title)
            Text("This app runs from the menu bar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
