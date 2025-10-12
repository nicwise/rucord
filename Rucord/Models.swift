import Foundation
import SwiftUI

struct OdometerEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let value: Int // kilometers

    init(id: UUID = UUID(), date: Date = Date(), value: Int) {
        self.id = id
        self.date = date
        self.value = value
    }
}

struct Car: Identifiable, Codable, Equatable {
    let id: UUID
    var plate: String
    var expiryOdometer: Int // when current RUC block expires (km)
    var entries: [OdometerEntry]
    var imageName: String? // filename for local image storage
    var wofExpiryDate: Date? // when WOF expires
    var registrationExpiryDate: Date? // when registration expires

    init(id: UUID = UUID(), plate: String, expiryOdometer: Int, entries: [OdometerEntry] = [], imageName: String? = nil, wofExpiryDate: Date? = nil, registrationExpiryDate: Date? = nil) {
        self.id = id
        self.plate = plate.uppercased()
        self.expiryOdometer = expiryOdometer
        self.entries = entries.sorted { $0.date < $1.date }
        self.imageName = imageName
        self.wofExpiryDate = wofExpiryDate
        self.registrationExpiryDate = registrationExpiryDate
    }
}

extension Car {
    var latestEntry: OdometerEntry? { entries.max(by: { $0.date < $1.date }) }
    var latestOdometer: Int { latestEntry?.value ?? 0 }
    var distanceRemaining: Int { max(expiryOdometer - latestOdometer, 0) }

    // Average km/day over the last 30 days (or overall if less data)
    var averagePerDayKM: Double {
        guard entries.count >= 2 else { return 0 }
        let sorted = entries.sorted { $0.date < $1.date }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        let recent = sorted.filter { $0.date >= cutoff }
        let use = recent.count >= 2 ? recent : sorted
        guard let first = use.first, let last = use.last, last.value > first.value else { return 0 }
        let days = max(Date.daysBetween(first.date, last.date), 1)
        return Double(last.value - first.value) / Double(days)
    }

    var projectedDaysRemaining: Double? {
        let rate = averagePerDayKM
        guard rate > 0 else { return nil }
        return Double(distanceRemaining) / rate
    }

    var projectedExpiryDate: Date? {
        guard let days = projectedDaysRemaining else { return nil }
        return Calendar.current.date(byAdding: .day, value: Int(ceil(days)), to: Date())
    }

    // WOF and Registration helper properties
    var wofDaysRemaining: Int? {
        guard let wofExpiryDate = wofExpiryDate else { return nil }
        return Date.daysBetween(Date(), wofExpiryDate)
    }

    var registrationDaysRemaining: Int? {
        guard let registrationExpiryDate = registrationExpiryDate else { return nil }
        return Date.daysBetween(Date(), registrationExpiryDate)
    }

    var wofDueSoon: Bool {
        guard let days = wofDaysRemaining else { return false }
        return days <= 42 // 6 weeks = 42 days
    }

    var registrationDueSoon: Bool {
        guard let days = registrationDaysRemaining else { return false }
        return days <= 42 // 6 weeks = 42 days
    }

    // For showing on main list - 2 months = ~60 days
    var wofDueWithin2Months: Bool {
        guard let days = wofDaysRemaining else { return false }
        return days <= 60
    }

    var registrationDueWithin2Months: Bool {
        guard let days = registrationDaysRemaining else { return false }
        return days <= 60
    }
}

extension Date {
    static func daysBetween(_ start: Date, _ end: Date) -> Int {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        return cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }
}
