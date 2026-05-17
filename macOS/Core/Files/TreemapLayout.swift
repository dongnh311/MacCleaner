import CoreGraphics

struct TreemapTile<Item: Identifiable>: Identifiable {
    var id: Item.ID { item.id }
    let item: Item
    let rect: CGRect
}

enum TreemapLayout {

    /// Squarified treemap. Items with non-positive value are skipped.
    static func layout<Item: Identifiable>(
        _ items: [Item],
        in container: CGRect,
        value: (Item) -> Double
    ) -> [TreemapTile<Item>] {
        let sorted = items
            .filter { value($0) > 0 }
            .sorted { value($0) > value($1) }
        guard !sorted.isEmpty else { return [] }
        let total = sorted.reduce(0.0) { $0 + value($1) }
        guard total > 0, container.width > 0, container.height > 0 else { return [] }

        var tiles: [TreemapTile<Item>] = []
        squarify(sorted, in: container, totalValue: total, value: value, into: &tiles)
        return tiles
    }

    private static func squarify<Item: Identifiable>(
        _ items: [Item],
        in rect: CGRect,
        totalValue: Double,
        value: (Item) -> Double,
        into tiles: inout [TreemapTile<Item>]
    ) {
        guard !items.isEmpty, rect.width > 0, rect.height > 0 else { return }
        if items.count == 1 {
            tiles.append(TreemapTile(item: items[0], rect: rect))
            return
        }

        let area = Double(rect.width * rect.height)
        let shortSide = Double(min(rect.width, rect.height))

        var rowItems: [Item] = [items[0]]
        var rowValue = value(items[0])

        for i in 1..<items.count {
            let candidateItems = rowItems + [items[i]]
            let candidateValue = rowValue + value(items[i])
            let candidateAR = worstAspectRatio(candidateItems, rowSum: candidateValue, total: totalValue, area: area, shortSide: shortSide, value: value)
            let currentAR = worstAspectRatio(rowItems, rowSum: rowValue, total: totalValue, area: area, shortSide: shortSide, value: value)
            if candidateAR <= currentAR {
                rowItems = candidateItems
                rowValue = candidateValue
            } else {
                break
            }
        }

        let rowFraction = rowValue / totalValue
        let isWideRect = rect.width >= rect.height

        let rowRect: CGRect
        let remainingRect: CGRect
        if isWideRect {
            let colWidth = CGFloat(rowFraction) * rect.width
            rowRect = CGRect(x: rect.minX, y: rect.minY, width: colWidth, height: rect.height)
            remainingRect = CGRect(x: rect.minX + colWidth, y: rect.minY, width: rect.width - colWidth, height: rect.height)

            var offset: CGFloat = rowRect.minY
            for item in rowItems {
                let frac = value(item) / rowValue
                let h = CGFloat(frac) * rowRect.height
                tiles.append(TreemapTile(item: item, rect: CGRect(x: rowRect.minX, y: offset, width: rowRect.width, height: h)))
                offset += h
            }
        } else {
            let rowHeight = CGFloat(rowFraction) * rect.height
            rowRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rowHeight)
            remainingRect = CGRect(x: rect.minX, y: rect.minY + rowHeight, width: rect.width, height: rect.height - rowHeight)

            var offset: CGFloat = rowRect.minX
            for item in rowItems {
                let frac = value(item) / rowValue
                let w = CGFloat(frac) * rowRect.width
                tiles.append(TreemapTile(item: item, rect: CGRect(x: offset, y: rowRect.minY, width: w, height: rowRect.height)))
                offset += w
            }
        }

        let remaining = Array(items[rowItems.count...])
        if !remaining.isEmpty {
            squarify(remaining, in: remainingRect, totalValue: totalValue - rowValue, value: value, into: &tiles)
        }
    }

    private static func worstAspectRatio<Item>(
        _ items: [Item],
        rowSum: Double,
        total: Double,
        area: Double,
        shortSide: Double,
        value: (Item) -> Double
    ) -> Double {
        guard !items.isEmpty, shortSide > 0, total > 0 else { return .infinity }
        let rowArea = rowSum / total * area
        guard rowArea > 0 else { return .infinity }
        let s2 = shortSide * shortSide
        var worst: Double = 0
        for item in items {
            let v = value(item) / total * area
            if v <= 0 { continue }
            let r1 = s2 * v / (rowArea * rowArea)
            let r2 = (rowArea * rowArea) / (s2 * v)
            worst = max(worst, max(r1, r2))
        }
        return worst
    }
}
