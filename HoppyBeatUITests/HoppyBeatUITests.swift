import XCTest

final class HoppyBeatUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testPlayClapTapSpeedAndRotate() {
        let app = XCUIApplication()
        app.launchArguments = ["-bpm", "96", "-beats", "4", "-kit", "wood", "-stars", "0", "-hat", "0"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        // Tap speed: several quick taps should move the tempo away from 96.
        let tapSpeed = app.buttons["Tap to set the speed"]
        XCTAssertTrue(tapSpeed.waitForExistence(timeout: 10))
        for _ in 0..<4 { tapSpeed.tap() }
        XCTAssertFalse(app.staticTexts["96"].exists, "Tap speed did not change the tempo")
        app.buttons["Bunny speed"].tap()
        XCTAssertTrue(app.staticTexts["96"].waitForExistence(timeout: 2))

        // Start, then clap on the pond: the "tap the pond" hint must go away once a clap lands.
        app.buttons["Play"].tap()
        let hint = app.staticTexts["Tap the pond on the beat! 👏"]
        XCTAssertTrue(hint.waitForExistence(timeout: 3))
        attach(app, "portrait-playing")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        XCTAssertTrue(hint.waitForNonExistence(timeout: 3), "Pond tap was not registered as a clap")
        app.buttons["Clap along"].tap()

        // Landscape: everything still reachable and on screen.
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        attach(app, "landscape-playing")
        for label in ["Stop", "Clap along", "Tap to set the speed", "Rocket speed", "More hops"] {
            XCTAssertTrue(app.buttons[label].isHittable, "\(label) not hittable in landscape")
        }
        app.buttons["Stop"].tap()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 2))

        XCUIDevice.shared.orientation = .portrait
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
