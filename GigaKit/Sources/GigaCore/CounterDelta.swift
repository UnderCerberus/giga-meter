import Foundation

enum CounterDelta {
    private static let wrapThreshold: UInt32 = 1 << 31
    private static let agreementTolerance: UInt32 = 10_000_000

    static func delta32(previous: UInt32, current: UInt32) -> UInt64 {
        if current >= previous { return UInt64(current - previous) }
        // 大きな値からの減少だけを周回とみなす。小さな値からの減少は個別リセット
        guard previous >= wrapThreshold else { return UInt64(current) }
        return UInt64(current) + (1 << 32) - UInt64(previous)
    }

    static func delta(
        previous32: UInt32,
        current32: UInt32,
        previous64: UInt64?,
        current64: UInt64?
    ) -> UInt64 {
        let narrow = delta32(previous: previous32, current: current32)
        guard let previous64, let current64 else { return narrow }
        guard current64 >= previous64 else { return current64 }

        let wide = current64 - previous64
        let difference = UInt32(truncatingIfNeeded: wide) &- UInt32(truncatingIfNeeded: narrow)
        // 64ビット値が32ビット値と食い違うなら信用しない
        return min(difference, 0 &- difference) <= agreementTolerance ? wide : narrow
    }
}
