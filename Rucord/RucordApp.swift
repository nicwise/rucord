//
//  RucordApp.swift
//  Rucord
//
//  Created by Nic Wise on 09/08/2025.
//

import SwiftUI

@main
struct RucordApp: App {
    @StateObject private var store = CarStore()
    
    var body: some Scene {
        WindowGroup {
            CarListView()
                .environmentObject(store)
        }
    }
}
