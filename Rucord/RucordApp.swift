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
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

@main
struct RucordApp: App {
    @StateObject private var store = CarStore()
    
    var body: some Scene {
        WindowGroup {
            CarListView()
                .environmentObject(store)
                .tint(Color(hex: 0x4ab1ff))
        }
    }
}
