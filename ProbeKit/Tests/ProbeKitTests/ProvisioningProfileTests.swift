import XCTest
@testable import ProbeKit

final class ProvisioningProfileTests: XCTestCase {
    private func profile(entitlements: String) -> Data {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>Entitlements</key><dict>\(entitlements)</dict></dict></plist>
        """
        return Data([0x30, 0x82, 0x00]) + Data(plist.utf8) + Data([0x00, 0xA0])
    }

    func testReadsGroupsFromSignedProfile() {
        let data = profile(entitlements: """
        <key>com.apple.security.application-groups</key>
        <array><string>group.a</string><string>group.b</string></array>
        """)
        XCTAssertEqual(ProvisioningProfile.appGroups(from: data), ["group.a", "group.b"])
    }

    func testReturnsEmptyWithoutGroups() {
        XCTAssertEqual(ProvisioningProfile.appGroups(from: profile(entitlements: "")), [])
    }

    func testReturnsEmptyWithoutPlist() {
        XCTAssertEqual(ProvisioningProfile.appGroups(from: Data([0x30, 0x82])), [])
    }
}
