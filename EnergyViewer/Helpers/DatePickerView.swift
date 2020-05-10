//
//  DatePickerView.swift
//  EnergyViewer
//
//  Created by Peter Bohac on 5/9/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI

struct DatePickerView: View {
    init(selectedDate: Date? = nil,
         backgroundColour: Color = .blue,
         foregroundColour: Color = .white,
         todayColour: Color = .red,
         selectedColour: Color = .orange,
         onDateSelected: ((Date) -> Void)? = nil) {

        self.vm = ViewModel(selectedDate: selectedDate ?? Date(),
                            backgroundColour: backgroundColour,
                            foregroundColour: foregroundColour,
                            todayColour: todayColour,
                            selectedColour: selectedColour,
                            onDateSelected: onDateSelected)
    }

    @ObservedObject private var vm: ViewModel
    @Environment(\.calendar) private var calendar

    private static var monthAndYear: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "arrowshape.turn.up.left.circle.fill")
                    .frame(minWidth: 40, minHeight: 40)
                    .onTapGesture {
                        self.vm.currentMonth = self.calendar.date(byAdding: .month, value: -1, to: self.vm.currentMonth)!
                    }
                Spacer()
                Text(Self.monthAndYear.string(from: vm.currentMonth))
                Spacer()
                Image(systemName: "calendar.circle.fill")
                    .foregroundColor(vm.todayColour)
                    .frame(minWidth: 40, minHeight: 40)
                    .onTapGesture {
                        self.vm.currentMonth = Date()
                    }
                Image(systemName: "arrowshape.turn.up.right.circle.fill")
                    .frame(minWidth: 40, minHeight: 40)
                    .onTapGesture {
                        self.vm.currentMonth = self.calendar.date(byAdding: .month, value: 1, to: self.vm.currentMonth)!
                    }
            }
            MonthView(month: vm.currentMonth)
                .environmentObject(vm)
        }
        .scaledToFit()
        .padding()
    }
}

fileprivate final class ViewModel: ObservableObject {
    @Published private(set) var selectedDate: Date
    @Published var currentMonth: Date
    let backgroundColour: Color
    let foregroundColour: Color
    let todayColour: Color
    let selectedColour: Color
    let onDateSelected: ((Date) -> Void)?

    init(selectedDate: Date,
         backgroundColour: Color,
         foregroundColour: Color,
         todayColour: Color,
         selectedColour: Color,
         onDateSelected: ((Date) -> Void)?) {

        self.selectedDate = selectedDate
        self.currentMonth = selectedDate
        self.backgroundColour = backgroundColour
        self.foregroundColour = foregroundColour
        self.todayColour = todayColour
        self.selectedColour = selectedColour
        self.onDateSelected = onDateSelected
    }

    func select(date: Date) {
        selectedDate = date
        onDateSelected?(date)
    }
}

fileprivate struct MonthView: View {
    let month: Date
    @Environment(\.calendar) private var calendar

    private var weeks: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        var weeks = calendar.generateDates(inside: monthInterval, matching: DateComponents(hour: 0, minute: 0, second: 0, weekday: 1))
        while weeks.count < 6 {
            weeks.append(Date(timeIntervalSince1970: 0))
        }
        return weeks
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .frame(minWidth: 40, minHeight: 40)
                }
            }
            ForEach(weeks, id: \.self) { week in
                WeekView(week: week, month: self.month)
            }
        }
    }
}

fileprivate struct WeekView: View {
    let week: Date
    let month: Date
    @Environment(\.calendar) private var calendar

    private var days: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: week) else { return [] }
        return calendar.generateDates(inside: weekInterval, matching: DateComponents(hour: 0, minute: 0, second: 0))
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { date in
                HStack {
                    if self.calendar.isDate(date, equalTo: self.month, toGranularity: .month) {
                        DayView(date: date)
                    } else {
                        DayView(date: date).hidden()
                    }
                }
            }
        }
    }
}

fileprivate struct DayView: View {
    let date: Date
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var vm: ViewModel

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    var body: some View {
        Text("30")
            .hidden()
            .padding(8)
            .frame(minWidth: 40, minHeight: 40)
            .background(isToday ? vm.todayColour : vm.backgroundColour)
            .clipShape(Circle())
            .overlay(
                ZStack {
                    Text(String(calendar.component(.day, from: date)))
                        .foregroundColor(vm.foregroundColour)
                    if calendar.isDate(date, inSameDayAs: vm.selectedDate) {
                        Circle().stroke(vm.selectedColour, lineWidth: 2)
                    }
                }
            )
            .onTapGesture {
                self.vm.select(date: self.date)
            }
    }
}

fileprivate extension Calendar {
    func generateDates(inside interval: DateInterval, matching components: DateComponents) -> [Date] {
        var dates: [Date] = []
        dates.append(interval.start)

        enumerateDates(startingAfter: interval.start, matching: components, matchingPolicy: .nextTime) { date, _, stop in
            if let date = date {
                if date < interval.end {
                    dates.append(date)
                } else {
                    stop = true
                }
            }
        }

        return dates
    }
}

struct DatePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            Group {
                DatePickerView(selectedDate: selectedDate)
            }
            .preferredColorScheme(colorScheme)
            .previewDisplayName("\(colorScheme)")
        }
        .previewLayout(.sizeThatFits).padding()
    }

    static let selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date())!
}
