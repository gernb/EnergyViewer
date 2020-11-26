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
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var body: some View {
        HStack {
            VStack(spacing: 5) {
                if isPhone {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: SourceView.width, maximum: SourceView.width))],
                        alignment: .center
                    ) { content }
                } else {
                    HStack { content }
                }
                if viewModel.stormModeActive {
                    Text("Storm Mode is Active")
                        .foregroundColor(.orange)
                }
                if showRawStatus {
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

    @ViewBuilder
    var content: some View {
        BatteryView(chargeLevel: viewModel.batteryChargePercent,
                    chargeText: viewModel.batteryChargeText,
                    subtitle: viewModel.batteryChargeSubtitle,
                    gridIsOffline: viewModel.gridIsOffline)
        ForEach(viewModel.sources) { source in
            SourceView(viewModel: source)
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
        return Self.height * CGFloat(chargeLevel) / 100.0
    }

    static var height: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 100 : 130
    }
    static var font: Font {
        UIDevice.current.userInterfaceIdiom == .phone ? .caption2 : .caption
    }

    var body: some View {
        VStack {
            Text("Battery Charge")
                .font(Self.font)
            Spacer()
            Text(chargeText)
            Spacer()
            Text(subtitle)
                .font(Self.font)
        }
        .foregroundColor(colorScheme == .dark ? .white : .black)
        .padding(5)
        .frame(height: Self.height - 4)
        .background(
            VStack {
                Spacer()
                Rectangle()
                    .fill(gridIsOffline ? Color.red : Color.green)
                    .frame(height: fillHeight)
            }
            .frame(height: Self.height - 4)
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

    static var width: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 100 : 150
    }
    static var height: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 100 : 130
    }
    static var font: Font {
        UIDevice.current.userInterfaceIdiom == .phone ? .title2 : .largeTitle
    }
    static var subtitleFont: Font {
        UIDevice.current.userInterfaceIdiom == .phone ? .caption : .body
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(viewModel.id)
            Text(viewModel.textPower)
                .font(Self.font)
            Text(viewModel.subtitle)
                .font(Self.subtitleFont)
        }
        .foregroundColor(.black)
        .padding(5)
        .frame(width: Self.width, height: Self.height)
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
        var stormModeActive = false
        var rawStatus = "rawStatus"
    }
}
