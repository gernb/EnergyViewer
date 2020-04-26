//
//  AlertItem.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/13/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let buttonText: String
    let action: (() -> Void)?
}
