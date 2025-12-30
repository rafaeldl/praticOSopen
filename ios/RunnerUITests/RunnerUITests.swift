import XCTest

@MainActor
class RunnerUITests: XCTestCase {
    var app: XCUIApplication!

    // Demo account credentials
    private let demoEmail = "demo@praticos.com.br"
    private let demoPassword = "Demo@2024!"

    override func setUp() {
        super.setUp()
        continueAfterFailure = true  // Continue even if assertions fail
        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    // MARK: - Main Test

    func testTakeScreenshots() {
        print("🚀 Starting screenshot capture...")
        sleep(5)

        // Check if logged in by looking for tab bar
        let isLoggedIn = app.staticTexts["Ordens de Serviço"].waitForExistence(timeout: 5)

        if isLoggedIn {
            print("📱 App is logged in - forcing logout")
            forceLogout()
            sleep(3)
        }

        // Take login screenshot
        snapshot("00_Login")
        print("📸 Login screenshot taken")

        // Perform login
        if doLogin() {
            print("✅ Login successful!")
            sleep(5)  // Wait for seed
            captureAllScreens()
        } else {
            print("❌ Login failed")
        }

        print("🏁 Done!")
    }

    // MARK: - Logout

    private func forceLogout() {
        print("🔓 Forcing logout...")

        // Tap "Mais" tab using coordinates (right side of tab bar)
        tapAtBottomTab(position: .right)
        sleep(2)

        // Swipe up to find Sair
        app.swipeUp()
        app.swipeUp()
        sleep(1)

        // Find and tap Sair
        let sairText = app.staticTexts["Sair"]
        if sairText.waitForExistence(timeout: 3) {
            sairText.tap()
            sleep(1)

            // Confirm in dialog - look for destructive button
            let confirmButtons = app.buttons.allElementsBoundByIndex
            for button in confirmButtons {
                if button.label == "Sair" {
                    button.tap()
                    print("✅ Logout confirmed")
                    sleep(3)
                    return
                }
            }
        }
        print("⚠️ Could not complete logout")
    }

    // MARK: - Login

    private func doLogin() -> Bool {
        print("🔑 Performing login...")
        sleep(2)

        // Find and tap "Entrar com email"
        let emailLink = app.staticTexts["Entrar com email"]
        guard emailLink.waitForExistence(timeout: 5) else {
            print("❌ 'Entrar com email' not found")
            return false
        }
        emailLink.tap()
        sleep(1)

        // Enter email
        let emailField = app.textFields.firstMatch
        guard emailField.waitForExistence(timeout: 3) else {
            print("❌ Email field not found")
            return false
        }
        emailField.tap()
        emailField.typeText(demoEmail)

        // Enter password
        let passwordField = app.secureTextFields.firstMatch
        guard passwordField.waitForExistence(timeout: 3) else {
            print("❌ Password field not found")
            return false
        }
        passwordField.tap()
        passwordField.typeText(demoPassword)

        // Tap Entrar button
        let entrarButton = app.buttons["Entrar"]
        guard entrarButton.waitForExistence(timeout: 3) else {
            print("❌ Entrar button not found")
            return false
        }
        entrarButton.tap()

        // Wait for home screen
        let success = app.staticTexts["Ordens de Serviço"].waitForExistence(timeout: 20)
        print(success ? "✅ Home screen loaded" : "❌ Home screen not found")
        return success
    }

    // MARK: - Capture Screenshots

    private func captureAllScreens() {
        // 1. Home
        sleep(3)
        snapshot("01_Home_OrderList")
        print("📸 Home captured")

        // 2. Dashboard - tap the chart icon in nav bar (second button from right)
        tapDashboardButton()
        sleep(3)
        snapshot("02_Dashboard_Financial")
        print("📸 Dashboard captured")

        // 3. Go back and navigate to Clientes
        tapBackButton()
        sleep(2)

        tapAtBottomTab(position: .center)  // Clientes is center tab
        sleep(3)
        snapshot("03_Customers_List")
        print("📸 Customers captured")

        // 4. Navigate to Mais (Settings)
        tapAtBottomTab(position: .right)  // Mais is right tab
        sleep(3)
        snapshot("04_Settings")
        print("📸 Settings captured")
    }

    // MARK: - Navigation Helpers

    private func tapDashboardButton() {
        print("📊 Tapping dashboard button...")

        // The dashboard button is in the navigation bar, second from right
        // Try to find it by looking at all buttons
        let allButtons = app.buttons.allElementsBoundByIndex
        for button in allButtons {
            let label = button.label.lowercased()
            // Look for chart-related button
            if label.contains("chart") || label.contains("painel") || label.contains("bar") {
                button.tap()
                print("✅ Found dashboard button: \(button.label)")
                return
            }
        }

        // Fallback: tap by coordinate (nav bar area, right side)
        // Based on screenshot: nav bar buttons are at top right
        let screenWidth = app.frame.width
        let navBarY: CGFloat = 110  // Approximate Y position of nav bar buttons
        let dashboardX = screenWidth - 120  // Second button from right

        let coord = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: dashboardX, dy: navBarY))
        coord.tap()
        print("✅ Tapped dashboard at coordinates")
    }

    private func tapBackButton() {
        print("🔙 Tapping back button...")

        // Try navigation bar back button first
        let navBackButton = app.navigationBars.buttons.element(boundBy: 0)
        if navBackButton.exists && navBackButton.isHittable {
            navBackButton.tap()
            print("✅ Tapped nav back button")
            return
        }

        // Fallback: tap at top-left corner where back button should be
        let coord = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 30, dy: 110))
        coord.tap()
        print("✅ Tapped back at coordinates")
    }

    enum TabPosition {
        case left    // Início
        case center  // Clientes
        case right   // Mais
    }

    private func tapAtBottomTab(position: TabPosition) {
        let screenWidth = app.frame.width
        let screenHeight = app.frame.height

        // Tab bar is at the bottom, approximately 50pt from bottom + safe area
        let tabY = screenHeight - 40

        let tabX: CGFloat
        switch position {
        case .left:
            tabX = screenWidth * 0.17  // ~1/6 from left
        case .center:
            tabX = screenWidth * 0.5   // Center
        case .right:
            tabX = screenWidth * 0.83  // ~5/6 from left
        }

        print("📍 Tapping tab at (\(tabX), \(tabY))")

        let coord = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: tabX, dy: tabY))
        coord.tap()
    }
}
