//
//  ContentView.swift
//  iosApp
//
//  Created by maochengfang on 2026/7/15.
//

import SwiftUI
import shared

struct ContentView: View {
    var body: some View {
        Text(Greeting().greet())
            .font(.title)
            .padding()
    }
}
