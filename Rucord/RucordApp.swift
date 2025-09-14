//
//  RucordApp.swift
//  Rucord
//
//  Created by Nic Wise on 09/08/2025.
//

import SwiftUI
import UserNotifications
import UIKit

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

final class RucordNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RucordNotificationDelegate()
    private let alertedKeyPrefix = "alerted_14days_"
    private let readingAlertedKeyPrefix = "alerted_reading_"
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if let token = notification.request.content.userInfo["rucToken"] as? String {
            UserDefaults.standard.set(true, forKey: alertedKeyPrefix + token)
        }
        if let rToken = notification.request.content.userInfo["readingToken"] as? String {
            UserDefaults.standard.set(true, forKey: readingAlertedKeyPrefix + rToken)
        }
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let token = response.notification.request.content.userInfo["rucToken"] as? String {
            UserDefaults.standard.set(true, forKey: alertedKeyPrefix + token)
        }
        if let rToken = response.notification.request.content.userInfo["readingToken"] as? String {
            UserDefaults.standard.set(true, forKey: readingAlertedKeyPrefix + rToken)
        }
        completionHandler()
    }
}

@main
struct RucordApp: App {
    @StateObject private var store = CarStore()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            CarListView()
                .environmentObject(store)
                .tint(Color(hex: 0x4ab1ff))
                .task { await setupNotifications() }
                .onReceive(store.$cars) { _ in
                    Task {
                        await scheduleRUCNotifications()
                        await scheduleReadingReminders()
                    }
                    refreshBadgeCount()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        refreshBadgeCount()
                    }
                }
        }
    }
    
    // MARK: - Notifications & Badges
    private func setupNotifications() async {
    let center = UNUserNotificationCenter.current()
    center.delegate = RucordNotificationDelegate.shared
    do {
    let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
    if granted {
        await scheduleRUCNotifications()
        await scheduleReadingReminders()
        }
    } catch {
        print("Notification auth error: \(error)")
        }
    }
    
    private func scheduleRUCNotifications() async {
        let center = UNUserNotificationCenter.current()
        
        // Remove any of our previously scheduled 14-day notifications to keep in sync with current cars
        await removeOurPendingRUCNotifications(center)
        
        for car in store.cars {
            guard let projectedDate = car.projectedExpiryDate else { continue }
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -14, to: projectedDate) else { continue }
            
            // Build dynamic body with days remaining
            let bodyText: String = {
                if car.distanceRemaining == 0 {
                    return "RUC expired for \(car.plate)."
                } else if let days = car.projectedDaysRemaining {
                    return "About \(Int(ceil(days))) days of RUC remaining for \(car.plate)."
                } else {
                    return "RUC due soon for \(car.plate)."
                }
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
                // Already within window: only alert once per (car, expiry)
                guard !hasAlerted(for: car) else { continue }
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                // Mark as alerted immediately to avoid repeat on next launch
                markAlerted(for: car)
            } else {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
                comps.hour = 9
                comps.minute = 0
                trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            }
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error {
                    print("Failed to schedule notification for \(car.plate): \(error)")
                }
            }
        }
    }
    
    private func removeOurPendingRUCNotifications(_ center: UNUserNotificationCenter) async {
        let requests: [UNNotificationRequest] = await withCheckedContinuation { cont in
            center.getPendingNotificationRequests { cont.resume(returning: $0) }
        }
        let ids = requests.map { $0.identifier }.filter { $0.hasPrefix("ruc_14days_") }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
    
    private let alertedKeyPrefix = "alerted_14days_"
    
    private func alertToken(for car: Car) -> String {
        return "\(car.id.uuidString)_\(car.expiryOdometer)"
    }
    
    private func hasAlerted(for car: Car) -> Bool {
        let token = alertToken(for: car)
        return UserDefaults.standard.bool(forKey: alertedKeyPrefix + token)
    }
    
    private func markAlerted(for car: Car) {
        let token = alertToken(for: car)
        UserDefaults.standard.set(true, forKey: alertedKeyPrefix + token)
    }
    
    private func nearExpiryCount() -> Int {
        let thresholdDays: Double = 14
        return store.cars.filter { car in
            if car.distanceRemaining == 0 { return true }
            if let days = car.projectedDaysRemaining { return days <= thresholdDays }
            return false
        }.count
    }
    
    private func refreshBadgeCount() {
    let count = nearExpiryCount()
    let center = UNUserNotificationCenter.current()
    center.setBadgeCount(count) { _ in }
    if count == 0 {
    center.removeAllDeliveredNotifications()
    }
    }
    
     // MARK: - Odometer Reading Reminders
     private let readingAlertedKeyPrefix = "alerted_reading_"
     
     private func readingAlertToken(for car: Car) -> String {
         let lastId = car.latestEntry?.id.uuidString ?? "none"
         let interval = car.entries.count < 3 ? 7 : 30
         return "\(car.id.uuidString)_\(lastId)_\(interval)"
     }
     
     private func hasReadingAlerted(for car: Car) -> Bool {
         let token = readingAlertToken(for: car)
         return UserDefaults.standard.bool(forKey: readingAlertedKeyPrefix + token)
     }
     
     private func markReadingAlerted(for car: Car) {
         let token = readingAlertToken(for: car)
         UserDefaults.standard.set(true, forKey: readingAlertedKeyPrefix + token)
     }
     
     private func removeOurPendingReadingNotifications(_ center: UNUserNotificationCenter) async {
         let requests: [UNNotificationRequest] = await withCheckedContinuation { cont in
             center.getPendingNotificationRequests { cont.resume(returning: $0) }
         }
         let ids = requests.map { $0.identifier }.filter { $0.hasPrefix("reading_") }
         if !ids.isEmpty {
             center.removePendingNotificationRequests(withIdentifiers: ids)
         }
     }
     
     private func scheduleReadingReminders() async {
         let center = UNUserNotificationCenter.current()
         await removeOurPendingReadingNotifications(center)
         
         for car in store.cars {
             // Determine interval based on number of readings
             let intervalDays = (car.entries.count < 3) ? 7 : 30
             let baseDate = car.latestEntry?.date ?? Date()
             guard let targetDate = Calendar.current.date(byAdding: .day, value: intervalDays, to: baseDate) else { continue }
             
             let content = UNMutableNotificationContent()
             content.title = "Odometer reading due"
             content.body = "Please add an odometer reading for \(car.plate)."
             content.sound = .default
             let token = readingAlertToken(for: car)
             content.userInfo = ["readingToken": token]
             
             let identifier = "reading_\(token)"
             let trigger: UNNotificationTrigger
             if targetDate <= Date() {
                 // If overdue, only alert once for this (car, lastEntry, interval) token
                 guard !hasReadingAlerted(for: car) else { continue }
                 trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                 // Mark immediately to avoid repeat on next launch until a new reading changes the token
                 markReadingAlerted(for: car)
             } else {
                 var comps = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
                 comps.hour = 9
                 comps.minute = 0
                 trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
             }
             
             let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
             center.add(request) { error in
                 if let error = error {
                     print("Failed to schedule reading reminder for \(car.plate): \(error)")
                 }
             }
         }
     }
 }

