import Foundation

public extension BinaryFloatingPoint {
    func interpolated(inputRange: [Self], outputRange: [Self]) -> Self {
        let count = Swift.min(inputRange.count, outputRange.count)
        guard count > 0 else { return 0 }
        guard count > 1 else { return outputRange[0] }
        guard self > inputRange[0] else { return outputRange[0] }

        for index in 1..<count {
            let x1 = inputRange[index - 1], x2 = inputRange[index]
            guard self <= x2 else { continue }
            let y1 = outputRange[index - 1], y2 = outputRange[index]
            // A zero-width segment has no slope to follow — snap to its end.
            guard x2 != x1 else { return y2 }
            return y1 + ((y2 - y1) / (x2 - x1)) * (self - x1)
        }

        return outputRange[count - 1]
    }

    func windowedProgress(index: Int, count: Int) -> Self {
        guard count > 0 else { return 0 }
        let start = Self(index) / Self(count)
        let end = Self(index + 1) / Self(count)
        return Swift.min(Swift.max((self - start) / (end - start), 0), 1)
    }
}
