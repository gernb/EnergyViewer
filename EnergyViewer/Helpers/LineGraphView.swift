//
//  LineGraphView.swift
//  EnergyViewer
//
//  Created by peter bohac on 4/14/20.
//  Copyright © 2020 1dot0 Solutions. All rights reserved.
//

import SwiftUI

struct LineGraphView: View {
    let data: LineGraphData

    @State private var isDragging = false
    @State private var dragLocation: CGPoint = .zero

    private var gesture: some Gesture {
        let dragGesture = DragGesture(minimumDistance: 0)
            .onChanged { value in
                self.dragLocation = value.location
                self.isDragging = true
            }
            .onEnded { _ in
                self.isDragging = false
                self.dragLocation = .zero
            }
        let pressGesture = LongPressGesture()
        return pressGesture.sequenced(before: dragGesture)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AxisView(minValue: self.data.yMin,
                         maxValue: self.data.yMax,
                         step: self.data.step(for: geometry),
                         geometry: geometry)

                ForEach(self.data.charts) { chart in
                    ChartView(data: chart.data,
                              colour: chart.colour,
                              step: self.data.step(for: geometry),
                              offset: self.data.yMin)
                }
                .modifier(FlipVertically())

                if self.isDragging {
                    DragView(location: self.dragLocation,
                             data: self.data,
                             step: self.data.step(for: geometry),
                             height: geometry.size.height)
                }
            }
            .contentShape(Rectangle())
            .gesture(self.gesture)
        }
        .padding(6)
        .drawingGroup()
    }
}

struct LineGraphData {
    struct ChartData: Identifiable {
        let id = UUID()
        let data: [Double]
        let colour: Color
        let descriptions: [String]
    }

    let charts: [ChartData]
    let xMax: Int
    let yMin: Double
    let yMax: Double

    fileprivate func step(for geometry: GeometryProxy) -> CGPoint {
        let yRange = abs(yMax) + abs(yMin)
        guard xMax > 0, yRange > 0 else {
            return CGPoint.zero
        }
        return CGPoint(x: geometry.size.width / CGFloat(xMax - 1),
                       y: geometry.size.height / CGFloat(yRange))
    }
}

fileprivate struct DragView: View {
    let location: CGPoint
    let data: LineGraphData
    let step: CGPoint
    let height: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var maxIndex: Int {
        guard let count = data.charts.first?.data.count else { return 0 }
        return count - 1
    }

    private var index: Int {
        let index = Int(max(location.x, 0) / step.x)
        return min(index, maxIndex)
    }

    private var dragLine: Path {
        var path = Path()
        path.move(to: CGPoint(x: CGFloat(index) * step.x, y: 0))
        path.addLine(to: CGPoint(x: CGFloat(index) * step.x, y: height))
        return path
    }

    private var controlColour: Color {
        self.colorScheme == .dark ? Color.white : Color.gray
    }

    var body: some View {
        ZStack {
            dragLine
                .stroke(controlColour, style: StrokeStyle(lineWidth: 1, dash: [5, 2]))
            HStack {
                VStack(alignment: .leading) {
                    ForEach(data.charts) { chart in
                        Text(chart.descriptions[self.index])
                            .font(.system(size: 12))
                            .foregroundColor(chart.colour == .clear ? self.controlColour : chart.colour)
                    }
                    Spacer()
                }
                Spacer()
            }.padding(.leading, 30)
        }
    }
}

fileprivate struct AxisView: View {
    let minValue: Double
    let maxValue: Double
    let step: CGPoint
    let geometry: GeometryProxy
    let tickSize: CGFloat = 5

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Group {
                yAxis.stroke(colorScheme == .dark ? Color.white : Color.gray, lineWidth: 1)
                xAxis.stroke(colorScheme == .dark ? Color.white : Color.gray, lineWidth: 1)
            }
            .modifier(FlipVertically())
            ForEach(xAxisTicks) { tick in
                Text(tick.label)
                    .font(.system(size: 8))
                    .padding(.top, self.minValue < 0 ? 25 : -15)
                    .position(x: tick.point.x, y: self.geometry.size.height - tick.point.y)
            }
            ForEach(yAxisTicks) { tick in
                Text(tick.label)
                    .font(.system(size: 8))
                    .frame(width: 50, alignment: .leading)
                    .position(x: tick.point.x + 35, y: self.geometry.size.height - tick.point.y)
            }
        }
        .opacity(0.5)
    }

    var yAxis: Path {
        var path = Path()

        path.move(to: CGPoint.zero)
        path.addLine(to: CGPoint(x: 0, y: geometry.size.height))

        for tick in yAxisTicks {
            path.move(to: tick.point)
            path.addLine(to: tick.point.offsettingX(by: tickSize))
        }

        return path
    }

    var yAxisTicks: [Tick] {
        let yOffset = CGFloat(-minValue) * step.y
        let topHalf: [Tick] = {
            let height = geometry.size.height - yOffset
            let yStep = height / 3.0
            return [
                Tick(point: CGPoint(x: 0, y: yOffset + yStep), label: String(format: "%.1f", maxValue / 3)),
                Tick(point: CGPoint(x: 0, y: yOffset + yStep * 2.0), label: String(format: "%.1f", 2 * maxValue / 3)),
                Tick(point: CGPoint(x: 0, y: yOffset + yStep * 3.0), label: String(format: "%.1f", maxValue))
            ]
        }()

        let bottomHalf: [Tick] = {
            let height = yOffset
            guard height > self.tickSize else { return [] }
            let yStep = height / 3.0
            if height <= 20 {
                return [
                    Tick(point: CGPoint.zero, label: String(format: "%.1f", minValue)),
                ]
            } else {
                return [
                    Tick(point: CGPoint.zero, label: String(format: "%.1f", minValue)),
                    Tick(point: CGPoint(x: 0, y: yStep), label: String(format: "%.1f", 2 * minValue / 3)),
                    Tick(point: CGPoint(x: 0, y: yStep * 2.0), label: String(format: "%.1f", minValue / 3))
                ]
            }
        }()

        return [topHalf, bottomHalf].flatMap { $0 }
    }

    var xAxis: Path {
        var path = Path()
        let yOffset = CGFloat(-minValue) * step.y

        path.move(to: CGPoint(x: 0, y: yOffset))
        path.addLine(to: CGPoint(x: geometry.size.width, y: yOffset))

        for tick in xAxisTicks {
            path.move(to: tick.point.offsettingY(by: -tickSize))
            path.addLine(to: tick.point.offsettingY(by: tickSize))
        }

        return path
    }

    var xAxisTicks: [Tick] {
        let yOffset = CGFloat(-minValue) * step.y
        let xStep = geometry.size.width / 12.0
        return zip(
            (1 ..< 12).map { CGPoint(x: xStep * CGFloat($0), y: yOffset) },
            ["2", "4", "6", "8", "10", "Noon", "2", "4", "6", "8", "10"]
        ).map { Tick(point: $0.0, label: $0.1 )}
    }

    struct Tick: Identifiable {
        let id = UUID()
        let point: CGPoint
        let label: String
    }
}

fileprivate struct ChartView: View {
    let data: [Double]
    let colour: Color
    let step: CGPoint
    let offset: Double

    var body: some View {
        ZStack {
            line
                .stroke(colour, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            shape
                .fill(colour)
                .opacity(0.25)
        }
    }

    var line: Path {
        var path = Path()
        guard data.count > 1 else { return path }

        let firstPoint = CGPoint(x: 0, y: CGFloat(data[0] - offset) * step.y)
        path.move(to: firstPoint)

        for idx in 1 ..< data.count {
            let p = CGPoint(x: step.x * CGFloat(idx), y: step.y * CGFloat(data[idx] - offset))
            path.addLine(to: p)
        }

        return path
    }

    var shape: Path {
        var path = Path()
        guard data.count > 1 else { return path }

        path.move(to: CGPoint(x: 0, y: CGFloat(-offset) * step.y))
        for idx in 0 ..< data.count {
            let p = CGPoint(x: step.x * CGFloat(idx), y: step.y * CGFloat(data[idx] - offset))
            path.addLine(to: p)
        }
        path.addLine(to: CGPoint(x: step.x * CGFloat(data.count - 1), y: CGFloat(-offset) * step.y))

        return path
    }
}

fileprivate struct FlipVertically: GeometryEffect {
    func effectValue(size: CGSize) -> ProjectionTransform {
        return ProjectionTransform(
            CGAffineTransform(scaleX: 1, y: -1)
                .translatedBy(x: 0, y: -size.height)
        )
    }
}

fileprivate extension CGPoint {
    func offsettingX(by offset: CGFloat) -> CGPoint {
        CGPoint(x: x + offset, y: y)
    }

    func offsettingY(by offset: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y + offset)
    }
}

struct LineGraphView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            LineGraphView(data: sampleData)
                .preferredColorScheme(colorScheme)
                .previewDisplayName("\(colorScheme)")
        }
        .previewLayout(.sizeThatFits).padding()
    }

    static let sampleData = LineGraphData(charts: charts, xMax: 10, yMin: -12, yMax: 25)

    static let charts = [
        LineGraphData.ChartData(data: [10, 20, 15, 25, 5, 8, -12], colour: .blue, descriptions: ["10", "20", "15", "25", "5", "8", "-12"]),
        LineGraphData.ChartData(data: [-4, 4, 10, 2, 10, 17, -7], colour: Color("GridPowerChart"), descriptions: ["-4", "4", "10", "2", "10"," 17", "-7"])
    ]
}
