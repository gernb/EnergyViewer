//
//  PowerHistoryView.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/13/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI

struct PowerHistoryView<ViewModel: PowerHistoryViewModel>: View {
    @StateObject var viewModel: ViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showDatePicker: Bool = false
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var body: some View {
        GeometryReader { geometry in

            HStack {
                Spacer()

                if geometry.size.width > 1000 {
                    VStack {
                        Text("Solar Destinations")
                            .foregroundColor(.yellow)
                        PieChartView(items: self.viewModel.energyTotal.solarDestinations)
                            .frame(maxWidth: 200)
                    }
                }

                VStack {
                    HStack {
                        Button(action: { self.viewModel.previousDay() }) {
                            Text(" << ")
                                .foregroundColor(self.colorScheme == .dark ? .white : .black)
                                .fontWeight(.bold)
                                .padding()
                                .overlay(Capsule().stroke(Color.gray, lineWidth: 2))
                        }
                        #if os(visionOS)
                        .buttonStyle(.plain)
                        #endif
                        Spacer()
                        Text(self.viewModel.date)
                            .font(isPhone ? .title2 : .title)
                            .onTapGesture { self.showDatePicker = true }
                            .popover(isPresented: self.$showDatePicker, arrowEdge: .top) {
                                DatePickerView(selectedDate: self.viewModel.currentDate) { date in
                                    self.viewModel.goto(date: date)
                                    self.showDatePicker = false
                                }
                            }
                        Spacer()
                        Button(action: { self.viewModel.nextDay() }) {
                            Text(" >> ")
                                .foregroundColor(self.viewModel.canAdvanceDate ? (self.colorScheme == .dark ? .white : .black) : .clear)
                                .fontWeight(.bold)
                                .padding()
                                .overlay(Capsule().stroke(self.viewModel.canAdvanceDate ? Color.gray : Color.clear, lineWidth: 2))
                        }
                        .disabled(!self.viewModel.canAdvanceDate)
                        #if os(visionOS)
                        .buttonStyle(.plain)
                        #endif
                    }
                    .padding(.bottom)
                    .frame(maxWidth: 600)

                    EnergyTotalsView(viewModel: self.viewModel)
                        .frame(minHeight: 75)
                        .frame(maxWidth: 400)
                    LineGraphView(data: LineGraphData(self.viewModel.powerData))
//                        .frame(maxWidth: geometry.size.width > 1050 ? .infinity : 799)

                    if geometry.size.width <= 1000 {
                        HStack {
                            VStack {
                                Text("Solar Destinations")
                                    .foregroundColor(.yellow)
                                PieChartView(items: self.viewModel.energyTotal.solarDestinations)
                                    .frame(maxWidth: 250)
                            }
                            VStack {
                                Text("House Sources")
                                    .foregroundColor(.blue)
                                PieChartView(items: self.viewModel.energyTotal.houseSources)
                                    .frame(maxWidth: 250)
                            }
                        }
                    }

                }
                .padding(5)

                if geometry.size.width > 1000 {
                    VStack {
                        Text("House Sources")
                            .foregroundColor(.blue)
                        PieChartView(items: self.viewModel.energyTotal.houseSources)
                            .frame(maxWidth: 200)
                    }
                }

                Spacer()
            }

        }
    }
}

struct EnergyTotalsView<ViewModel: PowerHistoryViewModel>: View {
    @ObservedObject var viewModel: ViewModel
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var body: some View {
        if isPhone {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 150))],
                      spacing: 9
            ) {
                content
            }
        } else {
            HStack(spacing: 9) {
                content
            }
        }
    }

    @ViewBuilder
    var content: some View {
        ToggleButton(isOn: $viewModel.showBattery, colour: .green) {
            VStack(spacing: 2) {
                HStack {
                    Text("from:")
                    Text(viewModel.energyTotal.fromBattery)
                }
                HStack {
                    Text("to:")
                    Text(viewModel.energyTotal.toBattery)
                }
            }
        }
        ToggleButton(isOn: $viewModel.showSolar, colour: .yellow) {
            Text(viewModel.energyTotal.solar)
        }
        ToggleButton(isOn: $viewModel.showHouse, colour: .blue) {
            Text(viewModel.energyTotal.house)
        }
        ToggleButton(isOn: $viewModel.showGrid, colour: .gray) {
            VStack(spacing: 2) {
                HStack {
                    Text("from:")
                    Text(viewModel.energyTotal.fromGrid)
                }
                HStack {
                    Text("to:")
                    Text(viewModel.energyTotal.toGrid)
                }
            }
        }
    }
}

struct ToggleButton<Content: View>: View {
    @Binding var isOn: Bool
    let colour: Color
    let content: Content

    init(isOn: Binding<Bool>, colour: Color, @ViewBuilder content: () -> Content) {
        self._isOn = isOn
        self.colour = colour
        self.content = content()
    }

    var body: some View {
        content
            .foregroundColor(colour)
            .padding()
            .frame(width: 150, height: 75)
            .overlay(
                Capsule().stroke(isOn ? colour : .clear, lineWidth: 2)
            )
            .onTapGesture { self.isOn.toggle() }
            .contentShape(.capsule)
            .hoverEffect()
    }
}

extension EnergyEndpoint: PieChartItem {
    var colour: Color {
        switch endpointType {
        case .battery: return .green
        case .grid: return .gray
        case .house: return .blue
        case .solar: return .yellow
        }
    }
}

fileprivate extension PowerData.SourceData {
    var colour: Color {
        switch source {
        case .battery: return .green
        case .grid: return Color("GridPowerChart")
        case .house: return .blue
        case .solar: return .yellow
        }
    }
}

fileprivate extension LineGraphData {
    init(_ data: PowerData) {
        self.xMax = data.rangeMax
        self.yMin = data.minValue
        self.yMax = data.maxValue
        if data.sources.isEmpty {
            self.charts = []
        } else {
            self.charts = [LineGraphData.ChartData(data: data.sources[0].values.map { _ in 0 },
                                                  colour: .clear,
                                                  descriptions: data.sources[0].values.map { Self.formatter.string(from: $0.timestamp) })] +
                data.sources.map { source in
                    LineGraphData.ChartData(data: source.values.map { $0.kW },
                                            colour: source.colour,
                                            descriptions: source.values.map { String(format: "%.2f kW", $0.kW) })
            }
        }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

struct PowerHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Group {
                PowerHistoryView(viewModel: PreviewPowerHistoryViewModel())
                PowerHistoryView(viewModel: loadingState)
            }
            .previewLayout(.fixed(width: 1194, height: 600))
            .preferredColorScheme(.dark)

            Group {
                PowerHistoryView(viewModel: PreviewPowerHistoryViewModel())
                PowerHistoryView(viewModel: loadingState)
            }
            .previewLayout(.fixed(width: 1024, height: 600))
            .preferredColorScheme(.dark)

            Group {
                PowerHistoryView(viewModel: PreviewPowerHistoryViewModel())
                PowerHistoryView(viewModel: loadingState)
            }
//            .previewLayout(.fixed(width: 834, height: 900))
            .preferredColorScheme(.dark)
        }
    }

    static let loadingState: PreviewPowerHistoryViewModel = {
        let vm = PreviewPowerHistoryViewModel()
        vm.energyTotal = .empty
        return vm
    }()

    final class PreviewPowerHistoryViewModel: PowerHistoryViewModel {
        var date: String = "Today"
        var currentDate: Date = Date()
        var canAdvanceDate: Bool = false
        var alert: AlertItem?
        var energyTotal = EnergyTotal(house: "22.0 kWh",
                                      solar: "63.1 kWh",
                                      fromBattery: "8.8 kWh",
                                      toBattery: "15.1 kWh",
                                      fromGrid: "0.2 kWh",
                                      toGrid: "35.0 kWh",
                                      houseSources: PreviewPowerHistoryViewModel.houseSources,
                                      solarDestinations: PreviewPowerHistoryViewModel.solarDestinations)
        var showBattery = true
        var showSolar = true
        var showHouse = true
        var showGrid = true
        var powerData: PowerData = .empty

        func nextDay() {}
        func previousDay() {}
        func goto(date: Date) {}

        static let houseSources = [
            EnergyEndpoint(isSource: true, endpointType: .solar, percentage: 78.1, kWh: 78.1),
            EnergyEndpoint(isSource: true, endpointType: .battery, percentage: 21.7, kWh: 21.7),
            EnergyEndpoint(isSource: true, endpointType: .grid, percentage: 0.2, kWh: 0.2),
        ]

        static let solarDestinations = [
            EnergyEndpoint(isSource: false, endpointType: .house, percentage: 25.4, kWh: 25.4),
            EnergyEndpoint(isSource: false, endpointType: .battery, percentage: 21.9, kWh: 21.9),
            EnergyEndpoint(isSource: false, endpointType: .grid, percentage: 52.6, kWh: 52.6),
        ]
    }
}
