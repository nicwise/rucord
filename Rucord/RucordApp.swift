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
                    Task { await scheduleRUCNotifications() }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        clearBadgesAndDeliveredNotifications()
                    }
                }
        }
    }
    
    // MARK: - Notifications & Badges
    private func setupNotifications() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await scheduleRUCNotifications()
            }
        } catch {
            print("Notification auth error: \(error)")
        }
    }
    
    private func scheduleRUCNotifications() async {
        let center = UNUserNotificationCenter.current()
        // Remove existing pending requests for our identifiers to avoid duplicates
        center.removeAllPendingNotificationRequests()
        
        for car in store.cars {
            guard let projectedDate = car.projectedExpiryDate else { continue }
            // Trigger 14 days before projected expiry
            guard let triggerDate = Calendar.current.date(byAdding: .day, value: -14, to: projectedDate) else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "RUC due soon"
            content.body = "\(car.plate) is estimated to have 14 days of RUC remaining."
            content.sound = .default
            content.badge = 1
            
            let identifier = "ruc_14days_\(car.id.uuidString)"
            let trigger: UNNotificationTrigger
            if triggerDate <= Date() {
                // If we're already within the window, trigger soon
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            } else {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
                // Optional: fire at 9am local time for visibility
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
    
    private func clearBadgesAndDeliveredNotifications() {
        // Clear app icon badge when app opens
        UIApplication.shared.applicationIconBadgeNumber = 0
        // Remove delivered notifications
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
