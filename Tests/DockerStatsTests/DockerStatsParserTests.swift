import XCTest
@testable import DockerStats

final class DockerStatsParserTests: XCTestCase {

    // MARK: - pct

    func testPctNormal() {
        XCTAssertEqual(DockerStatsParser.pct("3.20%"), 3.2, accuracy: 0.001)
    }

    func testPctZero() {
        XCTAssertEqual(DockerStatsParser.pct("0.00%"), 0.0, accuracy: 0.001)
    }

    func testPctMultiCore() {
        // Docker reports >100% when a container uses multiple cores
        XCTAssertEqual(DockerStatsParser.pct("203.5%"), 203.5, accuracy: 0.001)
    }

    func testPctNilAndEmpty() {
        XCTAssertEqual(DockerStatsParser.pct(nil), 0.0, accuracy: 0.001)
        XCTAssertEqual(DockerStatsParser.pct(""), 0.0, accuracy: 0.001)
    }

    // MARK: - bytes

    func testBytesBinaryUnits() {
        XCTAssertEqual(DockerStatsParser.bytes("512MiB"), 512 * 1_048_576,  accuracy: 1)
        XCTAssertEqual(DockerStatsParser.bytes("2GiB"),   2   * 1_073_741_824, accuracy: 1)
        XCTAssertEqual(DockerStatsParser.bytes("1KiB"),   1_024,             accuracy: 1)
    }

    func testBytesSIUnits() {
        XCTAssertEqual(DockerStatsParser.bytes("128MB"),  128_000_000, accuracy: 1)
        XCTAssertEqual(DockerStatsParser.bytes("1.5kB"),  1_500,       accuracy: 1)
        XCTAssertEqual(DockerStatsParser.bytes("1KB"),    1_000,       accuracy: 1)
    }

    func testBytesZero() {
        XCTAssertEqual(DockerStatsParser.bytes("0B"), 0, accuracy: 1)
    }

    func testBytesUnknownUnitReturnsZero() {
        XCTAssertEqual(DockerStatsParser.bytes("99XB"), 0, accuracy: 1)
    }

    // MARK: - slash

    func testSlashMemUsage() {
        let (used, limit) = DockerStatsParser.slash("512MiB / 2GiB")
        XCTAssertEqual(used,  512 * 1_048_576,     accuracy: 1)
        XCTAssertEqual(limit, 2 * 1_073_741_824,   accuracy: 1)
    }

    func testSlashZero() {
        let (a, b) = DockerStatsParser.slash("0B / 0B")
        XCTAssertEqual(a, 0, accuracy: 1)
        XCTAssertEqual(b, 0, accuracy: 1)
    }

    func testSlashMalformedReturnsZeros() {
        let (a, b) = DockerStatsParser.slash("not-a-slash-pair")
        XCTAssertEqual(a, 0, accuracy: 1)
        XCTAssertEqual(b, 0, accuracy: 1)
    }

    // MARK: - parse (full JSON line)

    func testParseValidLine() throws {
        let json = """
        {"BlockIO":"0B / 0B","CPUPerc":"3.20%","Container":"abc","ID":"abc",\
        "MemPerc":"25.00%","MemUsage":"512MiB / 2GiB","Name":"penpot-backend",\
        "NetIO":"1.5kB / 4kB","PIDs":"10"}
        """
        let s = try XCTUnwrap(DockerStatsParser.parse(json))
        XCTAssertEqual(s.name, "penpot-backend")
        XCTAssertEqual(s.cpuPercent,   3.2,              accuracy: 0.01)
        XCTAssertEqual(s.memPercent,   25.0,             accuracy: 0.01)
        XCTAssertEqual(s.memUsedBytes, 512 * 1_048_576,  accuracy: 1)
        XCTAssertEqual(s.netInBytes,   1_500,            accuracy: 1)
        XCTAssertEqual(s.netOutBytes,  4_000,            accuracy: 1)
    }

    func testParseInvalidJSON() {
        XCTAssertNil(DockerStatsParser.parse("not json"))
        XCTAssertNil(DockerStatsParser.parse(""))
    }

    func testParseEmptyObjectUsesDefaults() throws {
        // An empty JSON object should not crash and should return a stat with zero values
        let s = try XCTUnwrap(DockerStatsParser.parse("{}"))
        XCTAssertEqual(s.cpuPercent, 0, accuracy: 0.001)
    }

    // MARK: - container prefix filter

    func testContainerPrefixMatches() {
        XCTAssertTrue("penpot-backend".hasPrefix(DockerStatsParser.containerPrefix))
        XCTAssertTrue("penpot-frontend".hasPrefix(DockerStatsParser.containerPrefix))
        XCTAssertTrue("penpot-valkey".hasPrefix(DockerStatsParser.containerPrefix))
    }

    func testContainerPrefixRejects() {
        XCTAssertFalse("my-postgres".hasPrefix(DockerStatsParser.containerPrefix))
        XCTAssertFalse("redis".hasPrefix(DockerStatsParser.containerPrefix))
    }
}
