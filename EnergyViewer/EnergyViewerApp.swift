//
//  EnergyViewerApp.swift
//  EnergyViewer
//
//  Created by Peter Bohac on 10/29/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI

@main
struct EnergyViewerApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: NetworkHomeViewModel())
        }
    }
}
