//
//  RucordApp.swift
//  Rucord
//
//  Created by Nic Wise on 09/08/2025.
//

import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

@main
struct RucordApp: App {
    @StateObject var store = CarStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CarListView()
                .environmentObject(store)
                .tint(Color(hex: 0x4ab1ff))
                .onReceive(store.$cars) { cars in
                    Task {
                        if !cars.isEmpty {
                            await setupNotifications()
                        }
                        await scheduleRUCNotifications()
                        await scheduleReadingReminders()
                        await scheduleWOFRegistrationNotifications()
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
}
