//
//  ContentView.swift
//  Rucord
//
//  Created by Nic Wise on 09/08/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        CarListView()
    }
}

#Preview {
    CarListView()
        .environmentObject(CarStore())
}
