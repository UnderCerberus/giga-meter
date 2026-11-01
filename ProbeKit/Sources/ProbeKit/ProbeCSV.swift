import Foundation

public enum ProbeCSV {
    public static func make(samples: [ProbeSample]) -> String {
        let formatter = ISO8601DateFormatter()
        var csv = "date,trigger,boot_time,interface,in32,out32,in64,out64,note\n"
        for sample in samples {
            for counter in sample.interfaces {
                let fields = [
                    formatter.string(from: sample.date),
                    sample.trigger.rawValue,
                    formatter.string(from: sample.bootTime),
                    counter.name,
                    String(counter.in32),
                    String(counter.out32),
                    counter.in64.map(String.init) ?? "",
                    counter.out64.map(String.init) ?? "",
                    escape(sample.note ?? ""),
                ]
                csv += fields.joined(separator: ",") + "\n"
            }
        }
        return csv
    }

    private static func escape(_ text: String) -> String {
        guard text.contains(where: { ",\"\n".contains($0) }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
