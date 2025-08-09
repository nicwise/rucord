//
//  RUCBuddyApp.swift
//  RUCBuddy
//
//  Created by Nic Wise on 09/08/2025.
//

import SwiftUI

@main
struct RUCBuddyApp: App {
    @StateObject private var store = CarStore()
    
    var body: some Scene {
        WindowGroup {
            CarListView()
                .environmentObject(store)
        }
    }
}
