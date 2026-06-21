import SwiftUI

/// Live 2-minute download/upload speed graph shown in the dropdown menu.
struct SpeedGraphView: View {
    @ObservedObject var monitor: NetworkMonitor

    private var peak: Double {
        let maxValue = max(
            monitor.history.map { $0.down }.max() ?? 1,
            monitor.history.map { $0.up }.max()   ?? 1,
            1
        )
        return maxValue * 1.05
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                yAxis

                ZStack(alignment: .bottomLeading) {
                    Canvas { context, size in
                        drawGrid(in: context, size: size)
                        drawLine(samples: monitor.history.map { $0.down }, color: AppConstants.downloadColor, in: context, size: size)
                        drawLine(samples: monitor.history.map { $0.up },   color: AppConstants.uploadColor,   in: context, size: size)
                    }

                    xAxis
                }
            }
        }
    }

    // MARK: - Axis labels

    private var yAxis: some View {
        VStack(alignment: .leading) {
            Text(SpeedFormatter.compactMagnitude(bytesPerSec: peak))
            Spacer()
            Text(SpeedFormatter.compactMagnitude(bytesPerSec: peak / 2))
                .opacity(0.7)
            Spacer()
            Text("0")
        }
        .font(.system(.caption2, design: .monospaced))
        .foregroundStyle(.secondary)
        .frame(width: 52, alignment: .leading)
        .padding(.leading, 4)
    }

    private var xAxis: some View {
        HStack {
            Text("-2m").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text("-1m").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text("now").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Drawing

    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        let gridColor = Color.gray.opacity(0.18)
        let rows = 4
        for i in 0...rows {
            let y = (size.height / CGFloat(rows)) * CGFloat(i)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }

        let cols = 4
        for i in 0...cols {
            let x = (size.width / CGFloat(cols)) * CGFloat(i)
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func drawLine(samples: [Double], color: Color, in context: GraphicsContext, size: CGSize) {
        guard samples.count >= 2 else { return }

        let maxValue = max(samples.max() ?? 1, peak)
        let stepX = size.width / CGFloat(samples.count - 1)

        var path = Path()
        for (i, value) in samples.enumerated() {
            let x = CGFloat(i) * stepX
            let y = size.height - (CGFloat(value / maxValue) * size.height)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.8)

        var fill = path
        fill.addLine(to: CGPoint(x: CGFloat(samples.count - 1) * stepX, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        context.fill(fill, with: .color(color.opacity(0.15)))
    }
}
