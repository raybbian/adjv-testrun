//
//  ContentView.swift
//  adjv
//
//  Created by Raymond Bian on 6/13/24.
//

import SwiftUI
import Network

struct ContentView: View {
    var body: some View {
        StreamView()
            .edgesIgnoringSafeArea(.horizontal)
    }
}

#Preview {
    ContentView()
}
