# ギガメーター 検証版 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iPhoneの通信カウンタの実挙動を確かめる検証版「GigaProbe」を作り、実機に入れられるIPAをCIで生成する。

**Architecture:** 計測と保存のロジックをSwift Package `ProbeKit`に分離し、macOSのCIで自動テストする。SwiftUIアプリとWidgetKitウィジェットは`ProbeKit`を呼ぶだけの薄い層にする。WindowsにはSwiftとXcodeが無いため、テストとビルドはすべてGitHub Actionsで行う。

**Tech Stack:** Swift、SwiftUI、WidgetKit、BackgroundTasks、XCTest、XcodeGen、GitHub Actions(macOS)

**Spec:** `docs/superpowers/specs/2026-11-01-giga-meter-design.md`

**範囲:** 設計書9章の検証版のみ。本体(`GigaCore`、画面、月次集計)は、検証結果で未確定の判断を決めてから別の計画にする。

## Global Constraints

- 対応OS: iOS 17以降
- 外部へのデータ送信なし、広告なし、外部ライブラリなし(XcodeGenはCIのビルド道具としてのみ使用)
- 計測対象インターフェース: `pdp_ip`で始まるもの。検証用に`en0`も記録する
- 1GB = 1,000,000,000バイト
- リポジトリのルートは`C:\Claude\giga-meter`。`C:\Claude`の親リポジトリとは独立させ、親リポジトリにはコミットしない
- 計測CSVはリポジトリに入れない(`probe-data/`を除外)。`docs/probe-results.md`には結論と判断のみ記載する
- コミットの末尾に `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` を付ける

## ファイル構成

| パス | 役割 |
|---|---|
| `.gitignore` | 生成物と計測データの除外 |
| `.github/workflows/ci.yml` | テストとIPAビルド |
| `project.yml` | XcodeGenのプロジェクト定義 |
| `ProbeKit/Package.swift` | パッケージ定義 |
| `ProbeKit/Sources/ProbeKit/Models.swift` | 記録のデータ型 |
| `ProbeKit/Sources/ProbeKit/CounterReader.swift` | カウンタと起動時刻の読み取り |
| `ProbeKit/Sources/ProbeKit/ProbeStore.swift` | JSON Lines保存と記録処理 |
| `ProbeKit/Sources/ProbeKit/ProbeCSV.swift` | CSV生成 |
| `ProbeKit/Tests/ProbeKitTests/*.swift` | 自動テスト |
| `Probe/ProbeApp.swift` | アプリ本体とバックグラウンド更新 |
| `Probe/ContentView.swift` | 検証画面 |
| `ProbeWidget/ProbeWidget.swift` | 小サイズのウィジェット |
| `docs/probe-guide.md` | インストールと検証の手順 |
| `docs/probe-results.md` | 検証結果の記録 |

---

### Task 1: リポジトリとCIの土台

**Files:**
- Create: `.gitignore`
- Create: `.github/workflows/ci.yml`
- Create: `ProbeKit/Package.swift`
- Create: `ProbeKit/Sources/ProbeKit/Models.swift`
- Test: `ProbeKit/Tests/ProbeKitTests/ModelsTests.swift`

**Interfaces:**
- Produces: `InterfaceCounter`、`ProbeTrigger`、`ProbeSample`(下のコードのとおり)

- [ ] **Step 1: ローカルリポジトリを作成**

```bash
git -C /c/Claude/giga-meter init -b main
```

- [ ] **Step 2: `.gitignore`を作成**

```gitignore
*.xcodeproj/
.build/
build/
Payload/
*.ipa
Probe/Info.plist
Probe/GigaProbe.entitlements
ProbeWidget/Info.plist
ProbeWidget/GigaProbeWidget.entitlements
probe-data/
artifacts/
.DS_Store
```

- [ ] **Step 3: `ProbeKit/Package.swift`を作成**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ProbeKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ProbeKit", targets: ["ProbeKit"])],
    targets: [
        .target(name: "ProbeKit"),
        .testTarget(name: "ProbeKitTests", dependencies: ["ProbeKit"]),
    ]
)
```

- [ ] **Step 4: テストを作成**

`ProbeKit/Tests/ProbeKitTests/ModelsTests.swift`:

```swift
import XCTest
@testable import ProbeKit

final class ModelsTests: XCTestCase {
    func testSampleRoundTripsThroughJSON() throws {
        let sample = ProbeSample(
            date: Date(timeIntervalSince1970: 1000),
            trigger: .widget,
            bootTime: Date(timeIntervalSince1970: 500),
            interfaces: [
                InterfaceCounter(name: "pdp_ip0", in32: 1, out32: 2, in64: 3, out64: nil),
            ],
            note: "機内モードON"
        )
        let data = try JSONEncoder().encode(sample)
        XCTAssertEqual(try JSONDecoder().decode(ProbeSample.self, from: data), sample)
    }
}
```

- [ ] **Step 5: `Models.swift`を作成**

```swift
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
```

- [ ] **Step 6: CIを作成**

`.github/workflows/ci.yml`:

```yaml
name: ci
on:
  push:
  workflow_dispatch:
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift test --package-path ProbeKit
```

- [ ] **Step 7: コミットしてGitHubへ公開**

`VISIBILITY`はユーザーが選んだ`--public`または`--private`に置き換える。

```bash
git -C /c/Claude/giga-meter add .
git -C /c/Claude/giga-meter commit -m "chore: add spec, plan, ProbeKit models, and CI

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
gh repo create UnderCerberus/giga-meter VISIBILITY --source /c/Claude/giga-meter --push
```

- [ ] **Step 8: CIの成功を確認**

Run: `gh run watch --repo UnderCerberus/giga-meter --exit-status $(gh run list --repo UnderCerberus/giga-meter --limit 1 --json databaseId --jq '.[0].databaseId')`
Expected: `test`ジョブが成功し、`testSampleRoundTripsThroughJSON`がPASS

---

### Task 2: カウンタの読み取り

**Files:**
- Create: `ProbeKit/Sources/ProbeKit/CounterReader.swift`
- Test: `ProbeKit/Tests/ProbeKitTests/CounterReaderTests.swift`

**Interfaces:**
- Consumes: `InterfaceCounter`
- Produces:
  - `CounterReader.isTarget(name: String) -> Bool`
  - `CounterReader.readAll() -> [InterfaceCounter]`
  - `CounterReader.readTargets() -> [InterfaceCounter]`
  - `CounterReader.bootTime() -> Date`

- [ ] **Step 1: テストを作成**

```swift
import XCTest
@testable import ProbeKit

final class CounterReaderTests: XCTestCase {
    func testIsTargetAcceptsCellularAndWifiOnly() {
        XCTAssertTrue(CounterReader.isTarget(name: "pdp_ip0"))
        XCTAssertTrue(CounterReader.isTarget(name: "pdp_ip3"))
        XCTAssertTrue(CounterReader.isTarget(name: "en0"))
        XCTAssertFalse(CounterReader.isTarget(name: "en1"))
        XCTAssertFalse(CounterReader.isTarget(name: "lo0"))
    }

    func testReadAllIncludesLoopback() {
        XCTAssertTrue(CounterReader.readAll().contains { $0.name == "lo0" })
    }

    // 生バイト列のオフセットが正しいことを、32ビット値との一致で確かめる
    func test64BitLowWordMatches32BitCounter() throws {
        let counters = CounterReader.readAll().filter { $0.in64 != nil && $0.out64 != nil }
        XCTAssertFalse(counters.isEmpty)
        XCTAssertTrue(counters.contains { ($0.in64 ?? 0) > 0 })
        for c in counters {
            let inDiff = UInt32(truncatingIfNeeded: try XCTUnwrap(c.in64)) &- c.in32
            let outDiff = UInt32(truncatingIfNeeded: try XCTUnwrap(c.out64)) &- c.out32
            XCTAssertLessThan(min(inDiff, 0 &- inDiff), 10_000_000, c.name)
            XCTAssertLessThan(min(outDiff, 0 &- outDiff), 10_000_000, c.name)
        }
    }

    func testBootTimeIsInThePast() {
        let boot = CounterReader.bootTime()
        XCTAssertLessThan(boot, Date())
        XCTAssertGreaterThan(boot, Date(timeIntervalSince1970: 946_684_800))
    }
}
```

- [ ] **Step 2: 失敗を確認**

```bash
git -C /c/Claude/giga-meter add ProbeKit/Tests/ProbeKitTests/CounterReaderTests.swift
git -C /c/Claude/giga-meter commit -m "test: add CounterReader tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C /c/Claude/giga-meter push
```

Run: `gh run watch --repo UnderCerberus/giga-meter --exit-status $(gh run list --repo UnderCerberus/giga-meter --limit 1 --json databaseId --jq '.[0].databaseId')`
Expected: FAIL。`cannot find 'CounterReader' in scope`

- [ ] **Step 3: `CounterReader.swift`を作成**

```swift
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
```

- [ ] **Step 4: 成功を確認してコミット**

```bash
git -C /c/Claude/giga-meter add ProbeKit/Sources/ProbeKit/CounterReader.swift
git -C /c/Claude/giga-meter commit -m "feat: read interface counters and boot time

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C /c/Claude/giga-meter push
```

Run: `gh run watch --repo UnderCerberus/giga-meter --exit-status $(gh run list --repo UnderCerberus/giga-meter --limit 1 --json databaseId --jq '.[0].databaseId')`
Expected: 全テストPASS。`test64BitLowWordMatches32BitCounter`が失敗した場合は`if_msghdr2`のオフセットを疑い、値を推測で緩めない

---

### Task 3: 記録の保存とCSV

**Files:**
- Create: `ProbeKit/Sources/ProbeKit/ProbeStore.swift`
- Create: `ProbeKit/Sources/ProbeKit/ProbeCSV.swift`
- Test: `ProbeKit/Tests/ProbeKitTests/ProbeStoreTests.swift`

**Interfaces:**
- Consumes: `ProbeSample`、`ProbeTrigger`、`InterfaceCounter`、`CounterReader.readTargets()`、`CounterReader.bootTime()`
- Produces:
  - `ProbeStore(fileURL: URL, isShared: Bool)`、`.isShared: Bool`、`.append(_:) throws`、`.load() -> [ProbeSample]`
  - `ProbeStore.shared() -> ProbeStore`
  - `ProbeRecorder.record(trigger: ProbeTrigger, note: String?, store: ProbeStore) throws -> ProbeSample`(`@discardableResult`)
  - `ProbeCSV.make(samples: [ProbeSample]) -> String`

- [ ] **Step 1: テストを作成**

```swift
import XCTest
@testable import ProbeKit

final class ProbeStoreTests: XCTestCase {
    private var url: URL!
    private var store: ProbeStore!

    override func setUp() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jsonl")
        store = ProbeStore(fileURL: url, isShared: false)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
    }

    private func sample(_ seconds: TimeInterval, note: String? = nil) -> ProbeSample {
        ProbeSample(
            date: Date(timeIntervalSince1970: seconds),
            trigger: .app,
            bootTime: Date(timeIntervalSince1970: 0),
            interfaces: [InterfaceCounter(name: "pdp_ip0", in32: 10, out32: 20, in64: 30, out64: nil)],
            note: note
        )
    }

    func testLoadReturnsEmptyWhenFileIsMissing() {
        XCTAssertEqual(store.load(), [])
    }

    func testAppendKeepsOrder() throws {
        try store.append(sample(1))
        try store.append(sample(2))
        XCTAssertEqual(store.load(), [sample(1), sample(2)])
    }

    func testLoadSkipsBrokenLine() throws {
        try store.append(sample(1))
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("broken\n".utf8))
        try handle.close()
        try store.append(sample(2))
        XCTAssertEqual(store.load(), [sample(1), sample(2)])
    }

    func testRecordStoresOnlyTargetInterfaces() throws {
        let recorded = try ProbeRecorder.record(trigger: .manual, note: "メモ", store: store)
        XCTAssertEqual(recorded.trigger, .manual)
        XCTAssertEqual(recorded.note, "メモ")
        XCTAssertTrue(recorded.interfaces.allSatisfy { CounterReader.isTarget(name: $0.name) })
        XCTAssertEqual(store.load(), [recorded])
    }

    func testCSVHasOneRowPerInterfaceAndEscapesNote() {
        let csv = ProbeCSV.make(samples: [sample(0, note: "a,\"b\"")])
        XCTAssertEqual(
            csv,
            "date,trigger,boot_time,interface,in32,out32,in64,out64,note\n"
                + "1970-01-01T00:00:00Z,app,1970-01-01T00:00:00Z,pdp_ip0,10,20,30,,\"a,\"\"b\"\"\"\n"
        )
    }
}
```

- [ ] **Step 2: 失敗を確認**

```bash
git -C /c/Claude/giga-meter add ProbeKit/Tests/ProbeKitTests/ProbeStoreTests.swift
git -C /c/Claude/giga-meter commit -m "test: add store and CSV tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C /c/Claude/giga-meter push
```

Run: `gh run watch --repo UnderCerberus/giga-meter --exit-status $(gh run list --repo UnderCerberus/giga-meter --limit 1 --json databaseId --jq '.[0].databaseId')`
Expected: FAIL。`cannot find 'ProbeStore' in scope`

- [ ] **Step 3: `ProbeStore.swift`を作成**

```swift
import Foundation

public final class ProbeStore {
    public static let appGroupId = "group.com.undercerberus.gigaprobe"

    public let isShared: Bool
    private let fileURL: URL

    public init(fileURL: URL, isShared: Bool) {
        self.fileURL = fileURL
        self.isShared = isShared
    }

    // App Groupが使えない環境でも動かし、isSharedで結果を画面に出す
    public static func shared() -> ProbeStore {
        let manager = FileManager.default
        if let container = manager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            return ProbeStore(fileURL: container.appendingPathComponent("samples.jsonl"), isShared: true)
        }
        let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return ProbeStore(fileURL: documents.appendingPathComponent("samples.jsonl"), isShared: false)
    }

    public func append(_ sample: ProbeSample) throws {
        var line = try JSONEncoder().encode(sample)
        line.append(0x0A)

        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { url in
            do {
                if !FileManager.default.fileExists(atPath: url.path) {
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                }
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } catch {
                writeError = error
            }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    public func load() -> [ProbeSample] {
        var data: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
            data = try? Data(contentsOf: url)
        }
        guard let data else { return [] }
        let decoder = JSONDecoder()
        return data
            .split(separator: 0x0A)
            .compactMap { try? decoder.decode(ProbeSample.self, from: Data($0)) }
    }
}

public enum ProbeRecorder {
    @discardableResult
    public static func record(trigger: ProbeTrigger, note: String?, store: ProbeStore) throws -> ProbeSample {
        let sample = ProbeSample(
            date: Date(),
            trigger: trigger,
            bootTime: CounterReader.bootTime(),
            interfaces: CounterReader.readTargets(),
            note: note
        )
        try store.append(sample)
        return sample
    }
}
```

- [ ] **Step 4: `ProbeCSV.swift`を作成**

```swift
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
```

- [ ] **Step 5: 成功を確認してコミット**

```bash
git -C /c/Claude/giga-meter add ProbeKit/Sources/ProbeKit
git -C /c/Claude/giga-meter commit -m "feat: store samples as JSON Lines and export CSV

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C /c/Claude/giga-meter push
```

Run: `gh run watch --repo UnderCerberus/giga-meter --exit-status $(gh run list --repo UnderCerberus/giga-meter --limit 1 --json databaseId --jq '.[0].databaseId')`
Expected: 全テストPASS

---

### Task 4: アプリ、ウィジェット、IPAビルド

**Files:**
- Create: `project.yml`
- Create: `Probe/ProbeApp.swift`
- Create: `Probe/ContentView.swift`
- Create: `ProbeWidget/ProbeWidget.swift`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `CounterReader.readTargets()`、`CounterReader.bootTime()`、`ProbeStore.shared()`、`ProbeStore.isShared`、`ProbeStore.load()`、`ProbeRecorder.record(trigger:note:store:)`、`ProbeCSV.make(samples:)`
- Produces: CIの成果物`GigaProbe-ipa`(`GigaProbe.ipa`)

自動テストの対象外。このタスクの合格条件は、iOS向けビルドの成功とIPAの生成。画面の動作はTask 5の実機確認で見る。

- [ ] **Step 1: `project.yml`を作成**

```yaml
name: GigaProbe
options:
  bundleIdPrefix: com.undercerberus
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "5.0"
    TARGETED_DEVICE_FAMILY: "1"
packages:
  ProbeKit:
    path: ProbeKit
targets:
  GigaProbe:
    type: application
    platform: iOS
    sources: [Probe]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.undercerberus.gigaprobe
    dependencies:
      - package: ProbeKit
      - target: GigaProbeWidget
    entitlements:
      path: Probe/GigaProbe.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.undercerberus.gigaprobe
    info:
      path: Probe/Info.plist
      properties:
        CFBundleDisplayName: GigaProbe
        CFBundleShortVersionString: "0.1"
        CFBundleVersion: "1"
        UILaunchScreen: {}
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
        UIBackgroundModes: [fetch]
        BGTaskSchedulerPermittedIdentifiers:
          - com.undercerberus.gigaprobe.refresh
  GigaProbeWidget:
    type: app-extension
    platform: iOS
    sources: [ProbeWidget]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.undercerberus.gigaprobe.widget
    dependencies:
      - package: ProbeKit
    entitlements:
      path: ProbeWidget/GigaProbeWidget.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.undercerberus.gigaprobe
    info:
      path: ProbeWidget/Info.plist
      properties:
        CFBundleDisplayName: GigaProbe
        CFBundleShortVersionString: "0.1"
        CFBundleVersion: "1"
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
schemes:
  GigaProbe:
    build:
      targets:
        GigaProbe: all
```

- [ ] **Step 2: `Probe/ProbeApp.swift`を作成**

```swift
import BackgroundTasks
import ProbeKit
import SwiftUI

private let refreshTaskId = "com.undercerberus.gigaprobe.refresh"

private func scheduleRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

@main
struct ProbeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { scheduleRefresh() }
        }
        .backgroundTask(.appRefresh(refreshTaskId)) {
            try? ProbeRecorder.record(trigger: .background, note: nil, store: ProbeStore.shared())
            scheduleRefresh()
        }
    }
}
```

- [ ] **Step 3: `Probe/ContentView.swift`を作成**

```swift
import ProbeKit
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var samples: [ProbeSample] = []
    @State private var current: [InterfaceCounter] = []
    @State private var bootTime = Date()
    @State private var note = ""
    @State private var errorText: String?
    @State private var csvURL: URL?

    private let store = ProbeStore.shared()

    var body: some View {
        NavigationStack {
            List {
                Section("状態") {
                    LabeledContent("App Group", value: store.isShared ? "OK" : "NG")
                    LabeledContent("起動時刻", value: bootTime.formatted(date: .abbreviated, time: .standard))
                    LabeledContent("記録数", value: String(samples.count))
                    if let errorText {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
                Section("現在のカウンタ") {
                    ForEach(current, id: \.name) { counter in
                        VStack(alignment: .leading) {
                            Text(counter.name).font(.headline)
                            Text("32bit 受信 \(gb(UInt64(counter.in32))) 送信 \(gb(UInt64(counter.out32)))")
                            Text("64bit 受信 \(gb(counter.in64)) 送信 \(gb(counter.out64))")
                        }
                        .font(.footnote.monospacedDigit())
                    }
                }
                Section("手動記録") {
                    TextField("メモ(例: 機内モードON)", text: $note)
                    Button("今すぐ記録") {
                        record(.manual, note: note.isEmpty ? nil : note)
                        note = ""
                    }
                }
                Section("書き出し") {
                    if let csvURL {
                        ShareLink("CSVを共有", item: csvURL)
                    }
                }
                Section("履歴(新しい順に50件)") {
                    ForEach(Array(samples.suffix(50).reversed().enumerated()), id: \.offset) { _, sample in
                        VStack(alignment: .leading) {
                            Text("\(sample.date.formatted(date: .numeric, time: .standard)) \(sample.trigger.rawValue)")
                            if let note = sample.note {
                                Text(note).foregroundStyle(.secondary)
                            }
                        }
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("GigaProbe")
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { record(.app, note: nil) }
        }
    }

    private func record(_ trigger: ProbeTrigger, note: String?) {
        do {
            try ProbeRecorder.record(trigger: trigger, note: note, store: store)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
        samples = store.load()
        current = CounterReader.readTargets()
        bootTime = CounterReader.bootTime()
        writeCSV()
    }

    private func writeCSV() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gigaprobe.csv")
        do {
            try ProbeCSV.make(samples: samples).write(to: url, atomically: true, encoding: .utf8)
            csvURL = url
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func gb(_ bytes: UInt64?) -> String {
        guard let bytes else { return "取得不可" }
        return String(format: "%.3fGB", Double(bytes) / 1_000_000_000)
    }
}
```

- [ ] **Step 4: `ProbeWidget/ProbeWidget.swift`を作成**

```swift
import ProbeKit
import SwiftUI
import WidgetKit

struct ProbeEntry: TimelineEntry {
    let date: Date
    let isShared: Bool
    let widgetRecords: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ProbeEntry {
        ProbeEntry(date: Date(), isShared: true, widgetRecords: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProbeEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProbeEntry>) -> Void) {
        let store = ProbeStore.shared()
        try? ProbeRecorder.record(trigger: .widget, note: nil, store: store)
        let count = store.load().filter { $0.trigger == .widget }.count
        let entry = ProbeEntry(date: Date(), isShared: store.isShared, widgetRecords: count)
        completion(Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: 15 * 60))))
    }
}

struct ProbeWidgetView: View {
    let entry: ProbeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GigaProbe").font(.headline)
            Text("共有: \(entry.isShared ? "OK" : "NG")")
            Text("記録: \(entry.widgetRecords)回")
            Text(entry.date, style: .time)
        }
        .font(.caption)
    }
}

@main
struct ProbeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ProbeWidget", provider: Provider()) { entry in
            ProbeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("GigaProbe")
        .description("カウンタの検証用")
        .supportedFamilies([.systemSmall])
    }
}
```

- [ ] **Step 5: CIにIPAビルドを追加**

`.github/workflows/ci.yml`の全体を次の内容にする。アドホック署名でエンタイトルメントをIPAに残し、Sideloadlyの再署名時に引き継げるようにする。

```yaml
name: ci
on:
  push:
  workflow_dispatch:
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift test --package-path ProbeKit
  build:
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: brew install xcodegen
      - run: xcodegen generate
      - run: >
          xcodebuild
          -project GigaProbe.xcodeproj
          -scheme GigaProbe
          -configuration Release
          -sdk iphoneos
          -derivedDataPath build
          CODE_SIGNING_ALLOWED=NO
          build
      - name: Package IPA
        run: |
          APP=build/Build/Products/Release-iphoneos/GigaProbe.app
          codesign --force --sign - --entitlements ProbeWidget/GigaProbeWidget.entitlements "$APP/PlugIns/GigaProbeWidget.appex"
          codesign --force --sign - --entitlements Probe/GigaProbe.entitlements "$APP"
          mkdir Payload
          cp -R "$APP" Payload/
          zip -qry GigaProbe.ipa Payload
      - uses: actions/upload-artifact@v4
        with:
          name: GigaProbe-ipa
          path: GigaProbe.ipa
```

- [ ] **Step 6: コミットしてビルドを確認**

```bash
git -C /c/Claude/giga-meter add project.yml Probe ProbeWidget .github/workflows/ci.yml
git -C /c/Claude/giga-meter commit -m "feat: add probe app, widget, and IPA build

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C /c/Claude/giga-meter push
```

Run: `gh run watch --repo UnderCerberus/giga-meter --exit-status $(gh run list --repo UnderCerberus/giga-meter --limit 1 --json databaseId --jq '.[0].databaseId')`
Expected: `test`と`build`の両方が成功

- [ ] **Step 7: IPAを取得して中身を確認**

```bash
gh run download --repo UnderCerberus/giga-meter --name GigaProbe-ipa --dir /c/Claude/giga-meter/artifacts
```

```bash
python -c "import zipfile; names = zipfile.ZipFile(r'C:\Claude\giga-meter\artifacts\GigaProbe.ipa').namelist(); print([n for n in names if n.endswith(('GigaProbe', 'GigaProbeWidget', 'Info.plist'))])"
```

Expected: 一覧に`Payload/GigaProbe.app/GigaProbe`、`Payload/GigaProbe.app/PlugIns/GigaProbeWidget.appex/GigaProbeWidget`、両方の`Info.plist`が含まれる

---

### Task 5: 実機での検証手順と結果の記録

**Files:**
- Create: `docs/probe-guide.md`
- Create: `docs/probe-results.md`

**Interfaces:**
- Consumes: `artifacts/GigaProbe.ipa`
- Produces: 本体の実装計画の入力となる`docs/probe-results.md`

- [ ] **Step 1: `docs/probe-guide.md`を作成**

```markdown
# GigaProbe 検証手順

## インストール

1. Sideloadly公式サイトの案内に従い、Sideloadlyと必要なiTunes、iCloudをPCに入れる
2. iPhoneをUSBで接続し、PCを信頼する
3. Sideloadlyに`artifacts/GigaProbe.ipa`を指定する
4. Apple IDをSideloadlyに自分で入力してインストールする
5. iPhoneの「設定 → 一般 → VPNとデバイス管理」で開発元を信頼する
6. 求められた場合は「設定 → プライバシーとセキュリティ → デベロッパモード」をオンにする

無料Apple IDの署名は7日で切れる。切れたらSideloadlyで入れ直す。入れ直してもデータが残るかも確認する。

## 確認

各確認の前後でアプリを開き、「今すぐ記録」にメモを付けて記録する。

| # | 手順 | 見る点 |
|---|---|---|
| 1 | アプリを開く | `pdp_ip`の値が表示されるか。App GroupはOKか。64ビットは値が出るか |
| 2 | ウィジェットを追加する | 共有がOKか。記録回数が増えるか |
| 3 | モバイル通信で約200MB通信する | `pdp_ip`が増えるか。設定アプリの増加量と近いか |
| 4 | Wi-Fiで4.3GB以上通信する。OSや大きなアプリの更新を使ってよい | `en0`の32ビット値が0付近に戻るか。64ビット値は増え続けるか |
| 5 | 機内モードをオン、オフする | カウンタが減らないか |
| 6 | Wi-Fiとモバイル通信を切り替える | カウンタが減らないか |
| 7 | iPhoneを再起動する | 起動時刻が変わるか。カウンタが0付近に戻るか |
| 8 | アプリを閉じて3日間普段どおり使う | `background`と`widget`の記録がどの程度の頻度で増えるか |

4.3GBの確認はギガを消費しないようWi-Fiで行う。

## 結果の共有

「書き出し → CSVを共有」でCSVをPCへ送り、`probe-data/`に置く。共有方法はメールやクラウドストレージなど何でもよい。
```

- [ ] **Step 2: `docs/probe-results.md`を作成**

```markdown
# GigaProbe 検証結果

計測CSVは`probe-data/`に置き、リポジトリに入れない。この文書には結論のみ記載する。

| 確認項目 | 結果 | 判断 |
|---|---|---|
| `pdp_ip`の読み取り | 未実施 | 読めなければ開発中止 |
| 32ビット値の4.3GB周回 | 未実施 | 周回補正の要否 |
| 64ビット値の正しさ | 未実施 | 採用する値 |
| 機内モードと回線切替 | 未実施 | 値が減少した場合の判定方法 |
| 再起動の検出 | 未実施 | 増分計算 |
| バックグラウンド更新の頻度 | 未実施 | 再起動で失う量の見積もり |
| ウィジェットからの読み取り | 未実施 | ウィジェットでの記録の可否 |
| 無料Apple IDでの動作 | 未実施 | 配布方法 |
```

- [ ] **Step 3: コミット**

```bash
git -C /c/Claude/giga-meter add docs/probe-guide.md docs/probe-results.md
git -C /c/Claude/giga-meter commit -m "docs: add probe guide and results template

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C /c/Claude/giga-meter push
```

- [ ] **Step 4: ユーザーに手順書とIPAの場所を伝え、実機の確認を依頼**

ユーザーの確認が終わるまで次へ進まない。Apple IDの入力とインストールはユーザーが行う。

- [ ] **Step 5: 受け取ったCSVを解析して結果を記録**

`probe-data/`のCSVから次を集計し、`docs/probe-results.md`の結果と判断を埋める。

- `en0`と`pdp_ip*`の値が減った行の前後の値
- 64ビット値の増加量と32ビット値の増加量の差
- `boot_time`が変わった行
- `trigger`別の記録間隔の中央値

```bash
git -C /c/Claude/giga-meter add docs/probe-results.md
git -C /c/Claude/giga-meter commit -m "docs: record probe results

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C /c/Claude/giga-meter push
```

- [ ] **Step 6: 本体の実装計画を作成**

`docs/probe-results.md`の判断を設計書の5.1、5.3、9章、10章、11章に反映し、writing-plansスキルで本体の計画を`docs/superpowers/plans/`に作成する。
