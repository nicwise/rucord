import Foundation
import SwiftUI
import UIKit

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
    var colourHex: String
    var wofExpiryDate: Date? // when WOF expires
    var registrationExpiryDate: Date? // when registration expires
    var wofBooked: Bool? // has the WOF been booked

    private enum CodingKeys: String, CodingKey {
        case id
        case plate
        case expiryOdometer
        case entries
        case colourHex
        case wofExpiryDate
        case registrationExpiryDate
        case wofBooked
    }

    init(id: UUID = UUID(),
         plate: String,
         expiryOdometer: Int,
         entries: [OdometerEntry] = [],
         colourHex: String = "#3B82F6",
         wofExpiryDate: Date? = nil,
         registrationExpiryDate: Date? = nil,
         wofBooked: Bool? = nil) {
        self.id = id
        self.plate = plate.uppercased()
        self.expiryOdometer = expiryOdometer
        self.entries = entries.sorted { $0.date < $1.date }
        self.colourHex = colourHex
        self.wofExpiryDate = wofExpiryDate
        self.registrationExpiryDate = registrationExpiryDate
        self.wofBooked = wofBooked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        plate = try container.decode(String.self, forKey: .plate).uppercased()
        expiryOdometer = try container.decode(Int.self, forKey: .expiryOdometer)
        entries = try container.decode([OdometerEntry].self, forKey: .entries)
            .sorted { $0.date < $1.date }
        colourHex = try container.decodeIfPresent(String.self, forKey: .colourHex) ?? "#3B82F6"
        wofExpiryDate = try container.decodeIfPresent(Date.self, forKey: .wofExpiryDate)
        registrationExpiryDate = try container.decodeIfPresent(Date.self, forKey: .registrationExpiryDate)
        wofBooked = try container.decodeIfPresent(Bool.self, forKey: .wofBooked)
    }
}

extension Car {
    var displayColour: Color { Color(hex: colourHex) ?? .blue }

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

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        guard hex.count == 6,
              let value = Int(hex, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }

    var hexString: String? {
        guard let components = UIColor(self).cgColor.components else { return nil }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        if components.count >= 3 {
            red = components[0]
            green = components[1]
            blue = components[2]
        } else if let white = components.first {
            red = white
            green = white
            blue = white
        } else {
            return nil
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
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
