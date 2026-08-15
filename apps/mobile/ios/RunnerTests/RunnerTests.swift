import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testSceneManifestUsesWindowSceneWithFlutterDelegate() throws {
    let manifest = try XCTUnwrap(
      Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest")
        as? [String: Any]
    )
    let configurations = try XCTUnwrap(
      manifest["UISceneConfigurations"] as? [String: Any]
    )
    let applicationConfigurations = try XCTUnwrap(
      configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]]
    )
    let configuration = try XCTUnwrap(applicationConfigurations.first)

    XCTAssertEqual(configuration["UISceneClassName"] as? String, "UIWindowScene")
    XCTAssertEqual(
      configuration["UISceneDelegateClassName"] as? String,
      "Runner.SceneDelegate"
    )
  }

}
