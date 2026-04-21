import SwiftUI
import UserNotifications

extension RucordApp {
    func setupNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = RucordNotificationDelegate.shared

        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            if granted {
                await scheduleRUCNotifications()
                await scheduleReadingReminders()
                await scheduleWOFRegistrationNotifications()
            }
        } catch {
            print("Notification auth error: \(error)")
        }
    }

    func scheduleWOFRegistrationNotifications() async {
        let center = UNUserNotificationCenter.current()
        await removeOurPendingWOFRegistrationNotifications(center)

        for car in store.cars {
            await scheduleWOFNotification(for: car, center: center)
            await scheduleRegistrationNotification(for: car, center: center)
        }
    }

    func scheduleRUCNotifications() async {
        let center = UNUserNotificationCenter.current()
        await removeOurPendingRUCNotifications(center)

        for car in store.cars {
            guard let projectedDate = car.projectedExpiryDate else { continue }
            guard let triggerDate = Calendar.current.date(
                byAdding: .day,
                value: -14,
                to: projectedDate
            ) else {
                continue
            }

            let bodyText: String = {
                if car.distanceRemaining == 0 {
                    return "RUC expired for \(car.plate)."
                }
                if let days = car.projectedDaysRemaining {
                    return "About \(Int(ceil(days))) days of RUC remaining for \(car.plate)."
                }
                return "RUC due soon for \(car.plate)."
            }()

            let content = UNMutableNotificationContent()
            content.title = "RUC due soon"
            content.body = bodyText
            content.sound = .default
            let token = alertToken(for: car)
            content.userInfo = ["rucToken": token]

            let identifier = "ruc_14days_\(token)"
            let trigger: UNNotificationTrigger
            if triggerDate <= Date() {
                guard !hasAlerted(for: car) else { continue }
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                markAlerted(for: car)
            } else {
                trigger = scheduledCalendarTrigger(for: triggerDate)
            }

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule notification for \(car.plate): \(error)")
            }
        }
    }

    func removeOurPendingWOFRegistrationNotifications(
        _ center: UNUserNotificationCenter
    ) async {
        let requests: [UNNotificationRequest] = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests {
                continuation.resume(returning: $0)
            }
        }
        let wofIDs = requests.map(\.identifier).filter { $0.hasPrefix("wof_") }
        let registrationIDs = requests.map(\.identifier).filter {
            $0.hasPrefix("registration_")
        }
        let allIDs = wofIDs + registrationIDs
        if !allIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: allIDs)
        }
    }

    func wofAlertToken(for car: Car) -> String {
        let dateString = car.wofExpiryDate?.timeIntervalSince1970.description ?? "none"
        return "\(car.id.uuidString)_\(dateString)"
    }

    func registrationAlertToken(for car: Car) -> String {
        let dateString = car.registrationExpiryDate?.timeIntervalSince1970.description ?? "none"
        return "\(car.id.uuidString)_\(dateString)"
    }

    func hasWOFAlerted(for car: Car) -> Bool {
        let token = wofAlertToken(for: car)
        return UserDefaults.standard.bool(forKey: wofAlertedKeyPrefix + token)
    }

    func hasRegistrationAlerted(for car: Car) -> Bool {
        let token = registrationAlertToken(for: car)
        return UserDefaults.standard.bool(forKey: registrationAlertedKeyPrefix + token)
    }

    func markWOFAlerted(for car: Car) {
        let token = wofAlertToken(for: car)
        UserDefaults.standard.set(true, forKey: wofAlertedKeyPrefix + token)
    }

    func markRegistrationAlerted(for car: Car) {
        let token = registrationAlertToken(for: car)
        UserDefaults.standard.set(true, forKey: registrationAlertedKeyPrefix + token)
    }

    func removeOurPendingRUCNotifications(_ center: UNUserNotificationCenter) async {
        let requests: [UNNotificationRequest] = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests {
                continuation.resume(returning: $0)
            }
        }
        let identifiers = requests.map(\.identifier).filter {
            $0.hasPrefix("ruc_14days_")
        }
        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    func alertToken(for car: Car) -> String {
        "\(car.id.uuidString)_\(car.expiryOdometer)"
    }

    func hasAlerted(for car: Car) -> Bool {
        let token = alertToken(for: car)
        return UserDefaults.standard.bool(forKey: alertedKeyPrefix + token)
    }

    func markAlerted(for car: Car) {
        let token = alertToken(for: car)
        UserDefaults.standard.set(true, forKey: alertedKeyPrefix + token)
    }

    func carsWithExpiryIssues() -> Int {
        let thresholdDays: Double = 14
        return store.cars.filter { car in
            if car.distanceRemaining == 0 {
                return true
            }
            if let days = car.projectedDaysRemaining, days <= thresholdDays {
                return true
            }
            if car.wofDueSoon {
                let isBooked = car.wofBooked ?? false
                let isExpired = (car.wofDaysRemaining ?? 0) < 0
                if !isBooked || isExpired {
                    return true
                }
            }
            if car.registrationDueSoon {
                return true
            }
            return false
        }.count
    }

    func refreshBadgeCount() {
        let carsWithIssues = carsWithExpiryIssues()
        let center = UNUserNotificationCenter.current()

        center.setBadgeCount(carsWithIssues) { _ in }

        if carsWithIssues == 0 {
            center.removeAllDeliveredNotifications()
        }
    }

    func readingAlertToken(for car: Car) -> String {
        let lastID = car.latestEntry?.id.uuidString ?? "none"
        let interval = car.entries.count < 3 ? 7 : 30
        return "\(car.id.uuidString)_\(lastID)_\(interval)"
    }

    func hasReadingAlerted(for car: Car) -> Bool {
        let token = readingAlertToken(for: car)
        return UserDefaults.standard.bool(forKey: readingAlertedKeyPrefix + token)
    }

    func markReadingAlerted(for car: Car) {
        let token = readingAlertToken(for: car)
        UserDefaults.standard.set(true, forKey: readingAlertedKeyPrefix + token)
    }

    func removeOurPendingReadingNotifications(_ center: UNUserNotificationCenter) async {
        let requests: [UNNotificationRequest] = await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests {
                continuation.resume(returning: $0)
            }
        }
        let identifiers = requests.map(\.identifier).filter {
            $0.hasPrefix("reading_")
        }
        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    func scheduleReadingReminders() async {
        let center = UNUserNotificationCenter.current()
        await removeOurPendingReadingNotifications(center)

        for car in store.cars {
            let intervalDays = car.entries.count < 3 ? 7 : 30
            let baseDate = car.latestEntry?.date ?? Date()
            guard let targetDate = Calendar.current.date(
                byAdding: .day,
                value: intervalDays,
                to: baseDate
            ) else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "Odometer reading due"
            content.body = "Please add an odometer reading for \(car.plate)."
            content.sound = .default
            let token = readingAlertToken(for: car)
            content.userInfo = ["readingToken": token]

            let identifier = "reading_\(token)"
            let trigger: UNNotificationTrigger
            if targetDate <= Date() {
                guard !hasReadingAlerted(for: car) else { continue }
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                markReadingAlerted(for: car)
            } else {
                trigger = scheduledCalendarTrigger(for: targetDate)
            }

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule reading reminder for \(car.plate): \(error)")
            }
        }
    }

    private func scheduleWOFNotification(
        for car: Car,
        center: UNUserNotificationCenter
    ) async {
        guard let wofDate = car.wofExpiryDate,
              let triggerDate = Calendar.current.date(
                byAdding: .day,
                value: -42,
                to: wofDate
              ) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "WOF due soon"
        content.body = "WOF expires soon for \(car.plate). Time to book a service!"
        content.sound = .default
        let token = wofAlertToken(for: car)
        content.userInfo = ["wofToken": token]

        let identifier = "wof_\(token)"
        let trigger: UNNotificationTrigger
        if triggerDate <= Date() {
            guard !hasWOFAlerted(for: car) else { return }
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            markWOFAlerted(for: car)
        } else {
            trigger = scheduledCalendarTrigger(for: triggerDate)
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule WOF notification for \(car.plate): \(error)")
        }
    }

    private func scheduleRegistrationNotification(
        for car: Car,
        center: UNUserNotificationCenter
    ) async {
        guard let registrationDate = car.registrationExpiryDate,
              let triggerDate = Calendar.current.date(
                byAdding: .day,
                value: -42,
                to: registrationDate
              ) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Registration due soon"
        content.body = "Registration expires soon for \(car.plate). Time to renew!"
        content.sound = .default
        let token = registrationAlertToken(for: car)
        content.userInfo = ["registrationToken": token]

        let identifier = "registration_\(token)"
        let trigger: UNNotificationTrigger
        if triggerDate <= Date() {
            guard !hasRegistrationAlerted(for: car) else { return }
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            markRegistrationAlerted(for: car)
        } else {
            trigger = scheduledCalendarTrigger(for: triggerDate)
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            print(
                "Failed to schedule Registration notification for \(car.plate): \(error)"
            )
        }
    }

    private func scheduledCalendarTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
