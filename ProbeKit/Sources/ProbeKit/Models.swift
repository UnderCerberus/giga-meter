import Foundation

public struct InterfaceCounter: Codable, Equatable, Sendable {
    public let name: String
    public let in32: UInt32
    public let out32: UInt32
    public let in64: UInt64?
    public let out64: UInt64?

    public init(name: String, in32: UInt32, out32: UInt32, in64: UInt64?, out64: UInt64?) {
        self.name = name
        self.in32 = in32
        self.out32 = out32
        self.in64 = in64
        self.out64 = out64
    }
}

public enum ProbeTrigger: String, Codable, Sendable {
    case app, background, widget, manual
}

public struct ProbeSample: Codable, Equatable, Sendable {
    public let date: Date
    public let trigger: ProbeTrigger
    public let bootTime: Date
    public let interfaces: [InterfaceCounter]
    public let note: String?

    public init(date: Date, trigger: ProbeTrigger, bootTime: Date, interfaces: [InterfaceCounter], note: String?) {
        self.date = date
        self.trigger = trigger
        self.bootTime = bootTime
        self.interfaces = interfaces
        self.note = note
    }
}
