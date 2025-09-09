import SwiftUI

struct DateTimePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var startTimeText: String = ""
    @State private var endTimeText: String = ""
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Time Selection Section
            timeSelectionSection
            
            // Calendar Section
            calendarSection
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            startTimeText = dateFormatter.string(from: startDate)
            endTimeText = dateFormatter.string(from: endDate)
        }
    }
    
    private var timeSelectionSection: some View {
        HStack {
            // START field
            HStack(spacing: 8) {
                Text("START")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                TextField("HH:mm", text: $startTimeText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 60)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .onChange(of: startTimeText) { newValue in
                        let formatted = formatTimeInput(newValue)
                        if formatted != newValue {
                            startTimeText = formatted
                        }
                        updateStartTimeFromText(formatted)
                    }
            }
            
            Spacer()
            
            // STOP field
            HStack(spacing: 8) {
                Text("STOP")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                TextField("HH:mm", text: $endTimeText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 60)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .onChange(of: endTimeText) { newValue in
                        let formatted = formatTimeInput(newValue)
                        if formatted != newValue {
                            endTimeText = formatted
                        }
                        updateEndTimeFromText(formatted)
                    }
            }
        }
        .padding(20)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }
    
    private var calendarSection: some View {
        VStack(spacing: 0) {
            // Month/Year header with navigation
            HStack {
                Text(monthYearFormatter.string(from: currentMonth))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Day of week headers
            HStack(spacing: 0) {
                ForEach(0..<7) { dayIndex in
                    Text(dayOfWeekFormatter.string(from: getFirstDayOfWeek(for: currentMonth).addingTimeInterval(TimeInterval(dayIndex * 24 * 60 * 60))))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Separator line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 20)
            
            // Calendar grid
            calendarGrid
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }
    
    private var calendarGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<numberOfWeeksInMonth, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7) { dayIndex in
                        let dayDate = getDateForWeek(weekIndex, day: dayIndex)
                        let dayNumber = calendar.component(.day, from: dayDate)
                        let isCurrentMonth = calendar.isDate(dayDate, equalTo: currentMonth, toGranularity: .month)
                        let isSelected = calendar.isDate(dayDate, inSameDayAs: selectedDate)
                        let _ = calendar.isDateInToday(dayDate)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = dayDate
                                updateDatesWithSelectedDay()
                            }
                        }) {
                            Text("\(dayNumber)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isSelected ? .black : (isCurrentMonth ? .white : .white.opacity(0.3)))
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSelected ? Color.white : Color.clear)
                                        .opacity(isSelected ? 1.0 : 0.0)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!isCurrentMonth)
                    }
                }
                .padding(.horizontal, 20)
                
                if weekIndex < numberOfWeeksInMonth - 1 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Methods
    
    private func updateStartTimeFromText(_ timeText: String) {
        if let time = parseTimeString(timeText) {
            let components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            var newComponents = components
            newComponents.hour = time.hour
            newComponents.minute = time.minute
            
            if let newDate = calendar.date(from: newComponents) {
                startDate = newDate
            }
        }
    }
    
    private func updateEndTimeFromText(_ timeText: String) {
        if let time = parseTimeString(timeText) {
            let components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            var newComponents = components
            newComponents.hour = time.hour
            newComponents.minute = time.minute
            
            if let newDate = calendar.date(from: newComponents) {
                endDate = newDate
            }
        }
    }
    
    private func formatTimeInput(_ input: String) -> String {
        // Remove any non-digit characters
        let digitsOnly = input.filter { $0.isNumber }
        
        // Limit to 4 digits maximum
        let limitedDigits = String(digitsOnly.prefix(4))
        
        // Format based on length
        switch limitedDigits.count {
        case 0:
            return ""
        case 1:
            return limitedDigits
        case 2:
            return limitedDigits
        case 3:
            // Insert colon after first digit: "123" -> "1:23"
            let first = limitedDigits.prefix(1)
            let rest = limitedDigits.dropFirst()
            return "\(first):\(rest)"
        case 4:
            // Insert colon after second digit: "1234" -> "12:34"
            let firstTwo = limitedDigits.prefix(2)
            let lastTwo = limitedDigits.dropFirst(2)
            return "\(firstTwo):\(lastTwo)"
        default:
            return limitedDigits
        }
    }
    
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              hour >= 0 && hour <= 23,
              minute >= 0 && minute <= 59 else {
            return nil
        }
        return (hour: hour, minute: minute)
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func getFirstDayOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    private func getDateForWeek(_ week: Int, day: Int) -> Date {
        let firstDayOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let firstDayOfWeek = getFirstDayOfWeek(for: firstDayOfMonth)
        let daysToAdd = (week * 7) + day
        return calendar.date(byAdding: .day, value: daysToAdd, to: firstDayOfWeek) ?? firstDayOfMonth
    }
    
    private var numberOfWeeksInMonth: Int {
        let range = calendar.range(of: .weekOfYear, in: .month, for: currentMonth)
        return range?.count ?? 5
    }
    
    private func updateDatesWithSelectedDay() {
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        
        var newStartComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        newStartComponents.hour = startComponents.hour
        newStartComponents.minute = startComponents.minute
        
        var newEndComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        newEndComponents.hour = endComponents.hour
        newEndComponents.minute = endComponents.minute
        
        if let newStartDate = calendar.date(from: newStartComponents) {
            startDate = newStartDate
        }
        
        if let newEndDate = calendar.date(from: newEndComponents) {
            endDate = newEndDate
        }
        
        // Update text fields to reflect the new dates
        startTimeText = dateFormatter.string(from: startDate)
        endTimeText = dateFormatter.string(from: endDate)
    }
}


#Preview {
    DateTimePicker(
        startDate: .constant(Date()),
        endDate: .constant(Date().addingTimeInterval(3600))
    )
    .frame(width: 320)
    .padding()
    .background(Color.black)
}
