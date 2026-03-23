//
//  ContentView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//
//  This file is no longer used as the app is now menu bar only.
//  Keeping it for potential future use or testing.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("ZapCal")
                .font(.title)
            Text("This is a menu bar application.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

#Preview {
    ContentView()
}
