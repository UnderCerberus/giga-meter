import Foundation

public enum CounterReader {
    // iOS SDKに公開ヘッダが無い場合があるため、定数とオフセットを直接持つ
    private static let netRtIfList2: Int32 = 6
    private static let rtmIfInfo2: UInt8 = 0x12
    private static let indexOffset = 12
    private static let inBytesOffset = 96
    private static let outBytesOffset = 104
    private static let minMessageLength = 112

    public static func isTarget(name: String) -> Bool {
        name.hasPrefix("pdp_ip") || name == "en0"
    }

    public static func readAll() -> [InterfaceCounter] {
        let wide = read64()
        return read32()
            .map { name, value in
                InterfaceCounter(
                    name: name,
                    in32: value.in,
                    out32: value.out,
                    in64: wide[name]?.in,
                    out64: wide[name]?.out
                )
            }
            .sorted { $0.name < $1.name }
    }

    public static func readTargets() -> [InterfaceCounter] {
        readAll().filter { isTarget(name: $0.name) }
    }

    public static func bootTime() -> Date {
        var time = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &time, &size, nil, 0) == 0 else { return .distantPast }
        return Date(timeIntervalSince1970: Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000)
    }

    private static func read32() -> [String: (in: UInt32, out: UInt32)] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return [:] }
        defer { freeifaddrs(head) }

        var result: [String: (in: UInt32, out: UInt32)] = [:]
        var cursor = head
        while let pointer = cursor {
            let entry = pointer.pointee
            if let address = entry.ifa_addr,
               address.pointee.sa_family == UInt8(AF_LINK),
               let raw = entry.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self).pointee
                result[String(cString: entry.ifa_name)] = (data.ifi_ibytes, data.ifi_obytes)
            }
            cursor = entry.ifa_next
        }
        return result
    }

    private static func read64() -> [String: (in: UInt64, out: UInt64)] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, netRtIfList2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return [:] }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return [:] }

        var result: [String: (in: UInt64, out: UInt64)] = [:]
        buffer.withUnsafeBytes { bytes in
            var offset = 0
            while offset + 4 <= length {
                let messageLength = Int(bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                guard messageLength > 0, offset + messageLength <= length else { return }
                if bytes[offset + 3] == rtmIfInfo2, messageLength >= minMessageLength {
                    let index = bytes.loadUnaligned(fromByteOffset: offset + indexOffset, as: UInt16.self)
                    var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if if_indextoname(UInt32(index), &name) != nil {
                        result[String(cString: name)] = (
                            bytes.loadUnaligned(fromByteOffset: offset + inBytesOffset, as: UInt64.self),
                            bytes.loadUnaligned(fromByteOffset: offset + outBytesOffset, as: UInt64.self)
                        )
                    }
                }
                offset += messageLength
            }
        }
        return result
    }
}
