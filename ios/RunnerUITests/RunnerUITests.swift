import XCTest

@MainActor
class RunnerUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    func testTakeScreenshots() {
        // This is a simple test that takes a screenshot of the initial screen.
        // You can add more complex interactions here.
        
        // Wait for the app to load (Flutter apps might take a moment)
        Thread.sleep(forTimeInterval: 5)
        
        snapshot("01LoginScreen")
        
        // Example of interaction:
        // app.buttons["Login"].tap()
        // snapshot("02MainScreen")
    }
}
