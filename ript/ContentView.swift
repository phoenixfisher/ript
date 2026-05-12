//
//  ContentView.swift
//  ript
//
//  Created by Phoenix Fisher on 5/11/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {

    var body: some View {
        NavigationStack {
            VStack {
                Text("Let's get started")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
