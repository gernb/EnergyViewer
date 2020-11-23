//
//  PowerStatusView.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/13/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI

struct PowerStatusView<ViewModel: PowerStatusViewModel>: View {
    @ObservedObject var viewModel: ViewModel
    let showRawStatus: Bool

    var body: some View {
        HStack {
            VStack(spacing: 5) {
                HStack {
                    BatteryView(chargeLevel: viewModel.batteryChargePercent,
                                chargeText: viewModel.batteryChargeText,
                                subtitle: viewModel.batteryChargeSubtitle,
                                gridIsOffline: viewModel.gridIsOffline)
                    ForEach(viewModel.sources) { source in
                        SourceView(viewModel: source)
                    }
                }
                if (showRawStatus) {
                    Divider()
                    HStack {
                        Text(viewModel.rawStatus).lineLimit(nil)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .alert(item: $viewModel.alert) { item in
            Alert(title: Text(item.title),
                  message: Text(item.text),
                  dismissButton: .cancel(Text(item.buttonText), action: item.action ?? {}))
        }
    }
}

struct BatteryView: View {
    let chargeLevel: Double
    let chargeText: String
    let subtitle: String
    let gridIsOffline: Bool

    @Environment(\.colorScheme) var colorScheme

    var fillHeight: CGFloat {
        return CGFloat(130.0 * chargeLevel / 100.0)
    }

    var body: some View {
        VStack {
            Text("Battery Charge")
                .font(.caption)
            Spacer()
            Text(chargeText)
            Spacer()
            Text(subtitle)
                .font(.caption)
        }
        .foregroundColor(colorScheme == .dark ? .white : .black)
        .padding(5)
        .frame(height: 126)
        .background(
            VStack {
                Spacer()
                Rectangle()
                    .fill(gridIsOffline ? Color.red : Color.green)
                    .frame(height: fillHeight)
            }
            .frame(height: 126)
            .cornerRadius(10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(gridIsOffline ? Color.red : Color.green, lineWidth: 4)
        )
    }
}

struct SourceView: View {
    let viewModel: Source

    var body: some View {
        VStack(spacing: 10) {
            Text(viewModel.id)
            Text(viewModel.textPower)
                .font(.largeTitle)
            Text(viewModel.subtitle)
        }
        .foregroundColor(.black)
        .padding(5)
        .frame(width: 150, height: 130)
        .background(viewModel.colour)
        .cornerRadius(10)
    }
}

extension Source {
    var colour: Color {
        switch state {
        case .notInUse: return .gray
        case .consuming: return .red
        case .exporting: return .green
        case .generating: return .yellow
        case .house: return .blue
        }
    }
}

struct PowerStatusView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PowerStatusView(viewModel: PreviewPowerStatusViewModel(), showRawStatus: false)

            PowerStatusView(viewModel: loadingState, showRawStatus: false)

            BatteryView(chargeLevel: 50.0, chargeText: "50%", subtitle: "(15.1 / 27.0 kWh)", gridIsOffline: false)
            BatteryView(chargeLevel: 50.0, chargeText: "50%", subtitle: "(15.1 / 27.0 kWh)", gridIsOffline: true)

            SourceView(viewModel: Source(id: "Battery",
                                         subtitle: "(charging)",
                                         textPower: "1.2 kW",
                                         powerInKW: 1.2,
                                         state: .exporting))
        }
        .previewLayout(.sizeThatFits).padding()
        .preferredColorScheme(.dark)
    }

    static var loadingState: PreviewPowerStatusViewModel = {
        let vm = PreviewPowerStatusViewModel()
        vm.batteryChargePercent = 0
        vm.batteryChargeText = ""
        vm.batteryChargeSubtitle = ""
        vm.rawStatus = "Loading..."
        vm.sources = [
            Source(id: "Battery", subtitle: "", textPower: "", powerInKW: 0, state: .notInUse),
            Source(id: "Solar", subtitle: "", textPower: "", powerInKW: 0, state: .notInUse),
            Source(id: "House", subtitle: "", textPower: "", powerInKW: 0, state: .notInUse),
            Source(id: "Grid", subtitle: "", textPower: "", powerInKW: 0, state: .notInUse),
        ]
        return vm
    }()

    final class PreviewPowerStatusViewModel: PowerStatusViewModel {
        var alert: AlertItem?
        var batteryChargePercent = 93.4
        var batteryChargeText = "93%"
        var batteryChargeSubtitle = "(15.1 / 27.0 kWh)"
        var sources = [
            Source(id: "Battery",
                   subtitle: "(charging)",
                   textPower: "3.3 kW",
                   powerInKW: 3.3,
                   state: .exporting),
            Source(id: "Solar",
                   subtitle: "(generating)",
                   textPower: "10.0 kW",
                   powerInKW: 10.0,
                   state: .generating),
            Source(id: "House",
                   subtitle: "",
                   textPower: "4.2 kW",
                   powerInKW: 4.2,
                   state: .house),
            Source(id: "Grid",
                   subtitle: "",
                   textPower: "0.0 kW",
                   powerInKW: 0,
                   state: .notInUse)
        ]
        var gridIsOffline = false
        var rawStatus = "rawStatus"
    }
}
