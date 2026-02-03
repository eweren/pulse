import Foundation

enum PeriodDateRange {
    static let periodOptions = ["This week", "Last week", "This month", "Last month", "This year", "All time"]
    
    /// Returns (startDate, endDate) for the given period. endDate is nil for "All time".
    static func getDateRange(for timePeriod: String, calendar: Calendar, now: Date) -> (Date, Date?) {
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
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) ?? now
            return (startOfYear, endOfYear)
            
        case "All time":
            return (Date.distantPast, nil)
            
        default:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return (startOfMonth, endOfMonth)
        }
    }
}
