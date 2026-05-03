import Foundation

struct ContainerStats {
    let name: String
    let cpuPercent: Double
    let memUsedBytes: Double
    let memLimitBytes: Double
    let memPercent: Double
    let netInBytes: Double
    let netOutBytes: Double
}

enum DockerStatsParser {
    static let containerPrefix = "penpot-"

    static func parse(_ jsonLine: String) -> ContainerStats? {
        guard let data = jsonLine.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }
        let name   = obj["Name"] ?? obj["Container"] ?? "unknown"
        let cpu    = pct(obj["CPUPerc"])
        let (mu, ml) = slash(obj["MemUsage"] ?? "")
        let memPct = pct(obj["MemPerc"])
        let (ni, no) = slash(obj["NetIO"] ?? "")
        return ContainerStats(name: name, cpuPercent: cpu,
                              memUsedBytes: mu, memLimitBytes: ml, memPercent: memPct,
                              netInBytes: ni, netOutBytes: no)
    }

    static func pct(_ s: String?) -> Double {
        Double((s ?? "").replacingOccurrences(of: "%", with: "")
                        .trimmingCharacters(in: .whitespaces)) ?? 0
    }

    static func slash(_ s: String) -> (Double, Double) {
        let parts = s.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return (0, 0) }
        return (bytes(parts[0]), bytes(parts[1]))
    }

    static func bytes(_ s: String) -> Double {
        // Order matters: longer suffixes first to avoid partial matches (e.g. "MiB" before "B")
        let units: [(String, Double)] = [
            ("GiB", 1_073_741_824), ("MiB", 1_048_576), ("KiB", 1_024),
            ("GB",  1_000_000_000), ("MB",  1_000_000),
            ("kB",  1_000),         ("KB",  1_000),
            ("B",   1),
        ]
        for (suffix, multiplier) in units {
            if s.hasSuffix(suffix),
               let n = Double(s.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)) {
                return n * multiplier
            }
        }
        return Double(s.trimmingCharacters(in: .whitespaces)) ?? 0
    }
}
