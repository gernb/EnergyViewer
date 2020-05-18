//
//  PowerHistoryViewModel.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/13/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import Foundation
import Combine

struct EnergyEndpoint: Identifiable, CustomStringConvertible {
    enum EndpointType: CustomStringConvertible {
        case battery, solar, house, grid

        var description: String {
            switch self {
            case .battery: return "battery"
            case .solar: return "solar"
            case .house: return "house"
            case .grid: return "grid"
            }
        }
    }

    let isSource: Bool
    let endpointType: EndpointType
    let percentage: Double
    let kWh: Double

    typealias ID = EndpointType
    var id: EndpointType { endpointType }

    var description: String {
        String(format: "%.1f%% %@ %@ (%.1f kWh)", percentage, isSource ? "from" : "to", endpointType.description, kWh)
    }
}

struct EnergyTotal {
    let house: String
    let solar: String
    let fromBattery: String
    let toBattery: String
    let fromGrid: String
    let toGrid: String
    let houseSources: [EnergyEndpoint]
    let solarDestinations: [EnergyEndpoint]

    static let empty = EnergyTotal(house: "", solar: "", fromBattery: "", toBattery: "", fromGrid: "", toGrid: "", houseSources: [], solarDestinations: [])
}

struct PowerData {
    struct SourceData: Identifiable {
        enum SourceType {
            case battery, solar, house, grid
        }
        struct Value {
            let timestamp: Date
            let kW: Double
        }

        let source: SourceType
        let values: [Value]

        typealias ID = SourceType
        var id: SourceType { source }
    }

    let sources: [SourceData]
    let rangeMax: Int
    let maxValue: Double
    let minValue: Double

    static let empty = PowerData(sources: [], rangeMax: 10, maxValue: 1, minValue: -1)
}

protocol PowerHistoryViewModel: ObservableObject {
    var alert: AlertItem? { get set }
    var date: String { get }
    var currentDate: Date { get }
    var canAdvanceDate: Bool { get }
    var energyTotal: EnergyTotal { get }
    var showBattery: Bool { get set }
    var showSolar: Bool { get set }
    var showHouse: Bool { get set }
    var showGrid: Bool { get set }
    var powerData: PowerData { get }

    func nextDay()
    func previousDay()
    func goto(date: Date)
}

final class NetworkPowerHistoryViewModel: PowerHistoryViewModel {
    @Published var alert: AlertItem?
    @Published private(set) var date: String
    @Published private(set) var currentDate: Date
    @Published private(set) var canAdvanceDate: Bool
    @Published private(set) var energyTotal: EnergyTotal
    @Published var showBattery: Bool
    @Published var showSolar: Bool
    @Published var showHouse: Bool
    @Published var showGrid: Bool
    @Published private(set) var powerData: PowerData

    @Published private var powerDataPoints: [TeslaTimePeriodPower] = []
    private let siteId: Int
    private let userManager: UserManager
    private let networkModel: TeslaApi
    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init(siteId: Int, userManager: UserManager, networkModel: TeslaApi) {
        self.siteId = siteId
        self.userManager = userManager
        self.networkModel = networkModel
        self.date = "Today"
        self.currentDate = Date()
        self.canAdvanceDate = false
        self.energyTotal = .empty
        self.powerData = .empty

        if let showEnergyGraph = userManager.showEnergyGraph {
            self.showBattery = showEnergyGraph.battery
            self.showSolar = showEnergyGraph.solar
            self.showHouse = showEnergyGraph.house
            self.showGrid = showEnergyGraph.grid
        } else {
            self.showBattery = true
            self.showSolar = true
            self.showHouse = true
            self.showGrid = true
        }

        beginMonitoring()
    }

    func nextDay() {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        currentDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: next)!
    }

    func previousDay() {
        timerCancellable = nil
        let previous = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
        currentDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: previous)!
    }

    func goto(date: Date) {
        timerCancellable = nil
        let newDate = min(date, Date())
        currentDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: newDate)!
    }

    private func beginMonitoring() {
        monitorForLogout()
        monitorGraphSourceChanges()
        monitorForDayChanged()
        monitorSelectedDate()
    }

    private func monitorForLogout() {
        userManager.objectWillChange
            .sink { [weak self] in
                guard let strongSelf = self else { return }
                if !strongSelf.userManager.isAuthenticated {
                    strongSelf.timerCancellable = nil
                }
            }
            .store(in: &cancellables)
    }

    private func monitorGraphSourceChanges() {
        $showBattery.combineLatest($showSolar, $showHouse, $showGrid)
            .map { ($0.0, $0.1, $0.2, $0.3) }
            .assign(to: \.showEnergyGraph, on: userManager)
            .store(in: &cancellables)

        $powerDataPoints.combineLatest($showBattery.combineLatest($showSolar, $showHouse, $showGrid))
            .map(parse)
            .assign(to: \.powerData, on: self)
            .store(in: &cancellables)
    }

    private func monitorForDayChanged() {
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.currentDate = Date()
            }
            .store(in: &cancellables)
    }

    private func monitorSelectedDate() {
        $currentDate.sink { [weak self] date in
            guard let strongSelf = self else { return }
            strongSelf.powerData = .empty
            strongSelf.energyTotal = .empty
            if Calendar.current.isDateInToday(date) {
                strongSelf.loadData()
                strongSelf.canAdvanceDate = false
                strongSelf.date = "Today"
                strongSelf.pollForNewData()
            } else if Calendar.current.isDateInYesterday(date) {
                strongSelf.loadData(for: date)
                strongSelf.canAdvanceDate = true
                strongSelf.date = "Yesterday"
            } else {
                strongSelf.loadData(for: date)
                strongSelf.canAdvanceDate = true
                let formatter = DateFormatter()
                formatter.dateStyle = .full
                formatter.timeStyle = .none
                strongSelf.date = formatter.string(from: date)
            }
        }
        .store(in: &cancellables)
    }

    private func loadData(for date: Date? = nil) {
        guard userManager.isAuthenticated else { return }
        networkModel.energyHistory(for: siteId, period: .day, endDate: date)
            .receive(on: DispatchQueue.main)
            .catch(handleError)
            .compactMap(parse)
            .assign(to: \.energyTotal, on: self)
            .store(in: &cancellables)

        networkModel.powerHistory(for: siteId, endDate: date)
            .receive(on: DispatchQueue.main)
            .catch(handleError)
            .assign(to: \.powerDataPoints, on: self)
            .store(in: &cancellables)
    }

    private func pollForNewData() {
        guard userManager.isAuthenticated else { return }
        timerCancellable = Timer.publish(every: Constants.refreshInterval, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.loadData()
            }
    }

    private func parse(_ result: [TeslaTimePeriodEnergy]) -> EnergyTotal? {
        guard let data = result.first else { return nil }

        // House
        let houseTotal = data.consumerEnergyImportedFromGrid
            + data.consumerEnergyImportedFromSolar
            + data.consumerEnergyImportedFromBattery
            + data.consumerEnergyImportedFromGenerator
        let house = String(format: "%.1f kWh", houseTotal / 1000)
        let houseSources = [
            EnergyEndpoint(isSource: true, endpointType: .solar, percentage: 100.0 * data.consumerEnergyImportedFromSolar / houseTotal, kWh: data.consumerEnergyImportedFromSolar / 1000),
            EnergyEndpoint(isSource: true, endpointType: .battery, percentage: 100.0 * data.consumerEnergyImportedFromBattery / houseTotal, kWh: data.consumerEnergyImportedFromBattery / 1000),
            EnergyEndpoint(isSource: true, endpointType: .grid, percentage: 100.0 * data.consumerEnergyImportedFromGrid / houseTotal, kWh: data.consumerEnergyImportedFromGrid / 1000),
        ].filter { $0.percentage >= 0.1 }

        // Solar
        let solar = String(format: "%.1f kWh", data.solarEnergyExported / 1000)
        let solarDestinations = [
            EnergyEndpoint(isSource: false, endpointType: .house, percentage: 100.0 * data.consumerEnergyImportedFromSolar / data.solarEnergyExported, kWh: data.consumerEnergyImportedFromSolar / 1000),
            EnergyEndpoint(isSource: false, endpointType: .battery, percentage: 100.0 * data.batteryEnergyImportedFromSolar / data.solarEnergyExported, kWh: data.batteryEnergyImportedFromSolar / 1000),
            EnergyEndpoint(isSource: false, endpointType: .grid, percentage: 100.0 * data.gridEnergyExportedFromSolar / data.solarEnergyExported, kWh: data.gridEnergyExportedFromSolar / 1000),
        ].filter { $0.percentage >= 0.1 }

        // Battery
        let fromBattery = String(format: "%.1f kWh", data.batteryEnergyExported / 1000)
        let toBatteryTotal = data.batteryEnergyImportedFromGenerator
            + data.batteryEnergyImportedFromGrid
            + data.batteryEnergyImportedFromSolar
        let toBattery = String(format: "%.1f kWh", toBatteryTotal / 1000)

        // Grid
        let fromGrid = String(format: "%.1f kWh", data.gridEnergyImported / 1000)
        let toGridTotal = data.gridEnergyExportedFromSolar
            + data.gridEnergyExportedFromBattery
            + data.gridEnergyExportedFromGenerator
        let toGrid = String(format: "%.1f kWh", toGridTotal / 1000)

        return EnergyTotal(house: house,
                           solar: solar,
                           fromBattery: fromBattery,
                           toBattery: toBattery,
                           fromGrid: fromGrid,
                           toGrid: toGrid,
                           houseSources: houseSources,
                           solarDestinations: solarDestinations)
    }

    private func parse(data: [TeslaTimePeriodPower], show: (battery: Bool, solar: Bool, house: Bool, grid: Bool)) -> PowerData {
        var minValue: Double = 0
        var maxValue: Double = 0
        var batteryValues: [PowerData.SourceData.Value] = []
        var solarValues: [PowerData.SourceData.Value] = []
        var houseValues: [PowerData.SourceData.Value] = []
        var gridValues: [PowerData.SourceData.Value] = []

        for timePeriod in data {
            let values = [
                timePeriod.batteryPower / 1000,
                timePeriod.solarPower / 1000,
                (timePeriod.batteryPower + timePeriod.solarPower + timePeriod.gridPower) / 1000,
                timePeriod.gridPower / 1000
            ]
            minValue = min(minValue, values.min() ?? 0)
            maxValue = max(maxValue, values.max() ?? 0)
            batteryValues.append(PowerData.SourceData.Value(timestamp: timePeriod.timestamp, kW: values[0]))
            solarValues.append(PowerData.SourceData.Value(timestamp: timePeriod.timestamp, kW: values[1]))
            houseValues.append(PowerData.SourceData.Value(timestamp: timePeriod.timestamp, kW: values[2]))
            gridValues.append(PowerData.SourceData.Value(timestamp: timePeriod.timestamp, kW: values[3]))
        }

        let sources = zip([
            PowerData.SourceData(source: .house, values: houseValues),
            PowerData.SourceData(source: .battery, values: batteryValues),
            PowerData.SourceData(source: .solar, values: solarValues),
            PowerData.SourceData(source: .grid, values: gridValues),
        ], [
            show.house,
            show.battery,
            show.solar,
            show.grid,
        ]).filter { $0.1 }.map { $0.0 } // exclude sources that aren't being shown
        return PowerData(sources: sources, rangeMax: Constants.dailyChartPoints, maxValue: maxValue, minValue: minValue)
    }

    private func handleError<T>(_ error: Swift.Error) -> Empty<T, Never> {
        switch error {
        case TeslaApiError.httpUnauthorised:
            alert = AlertItem(title: "Error", text: "You have been logged out.", buttonText: "Ok") { [userManager] in
                userManager.logout()
            }
        default:
            alert = AlertItem(title: "Error", text: "\(error)", buttonText: "Ok", action: nil)
        }
        return Empty(completeImmediately: true)
    }

    private enum Constants {
        static let refreshInterval: TimeInterval = 60
        static let dailyChartPoints: Int = (24 * 60) / 5 // power data points come in 5-min intervals
    }
}
