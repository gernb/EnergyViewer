//
//  PieChartView.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/14/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI

struct PieChartView<Item: PieChartItem>: View {
    let items: [Item]

    var body: some View {
        VStack {
            ChartView(data: ChartData(items: items))
                .padding()
                .scaledToFit()
            ForEach(items) { item in
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(item.colour)
            }
        }
    }
}

protocol PieChartItem: Identifiable, CustomStringConvertible {
    var percentage: Double { get }
    var colour: Color { get }
}

fileprivate struct ChartView<Item: PieChartItem>: View {
    let data: ChartData<Item>

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(self.data.slices) { slice in
                    SliceView(geometry: geometry, data: slice)
                }
            }
        }
    }
}

fileprivate struct SliceView<Item: PieChartItem>: View {
    let geometry: GeometryProxy
    let data: SliceData<Item>

    var path: Path {
        let chartSize = geometry.size.width
        let radius = chartSize / 2
        let centerX = radius
        let centerY = radius

        var path = Path()
        path.move(to: CGPoint(x: centerX, y: centerY))
        path.addArc(center: CGPoint(x: centerX, y: centerY),
                    radius: radius,
                    startAngle: data.startAngle,
                    endAngle: data.endAngle,
                    clockwise: false)
        return path
    }

    public var body: some View {
        path.fill(data.item.colour)
            .overlay(path.stroke(Color.white, lineWidth: 2))
    }
}


fileprivate struct SliceData<Item: PieChartItem>: Identifiable {
    typealias ID = Item.ID
    var id: ID { item.id }
    var item: Item
    var startAngle: Angle
    var endAngle: Angle
}

fileprivate struct ChartData<Item: PieChartItem> {
    let slices: [SliceData<Item>]

    init(items: [Item]) {
        var currentAngle: Double = -90
        var slices: [SliceData<Item>] = []

        for item in items {
            let angle = 360 * item.percentage / 100.0
            let slice = SliceData(item: item,
                                  startAngle: .degrees(currentAngle),
                                  endAngle: .degrees(currentAngle + angle))
            currentAngle += angle
            slices.append(slice)
        }

        self.slices = slices
    }
}

struct PieChartView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            Group {
                PieChartView(items: [
                    Item(percentage: 33.3, colour: .red),
                    Item(percentage: 33.3, colour: .green),
                    Item(percentage: 33.3, colour: .blue)
                ])

                PieChartView(items: [
                    Item(percentage: 20, colour: .orange),
                    Item(percentage: 35, colour: .yellow),
                    Item(percentage: 45, colour: .purple)
                ])
            }
            .preferredColorScheme(colorScheme)
            .previewDisplayName("\(colorScheme)")
        }
        .previewLayout(.sizeThatFits).padding()
    }

    struct Item: PieChartItem {
        var percentage: Double
        var colour: Color
        let id = UUID()
        var description: String { String(format: "%.0f%% %@", percentage, colour.description) }
    }
}
