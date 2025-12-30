import XCTest

@MainActor
class RunnerUITests: XCTestCase {
    var app: XCUIApplication!

    private let demoEmail = "demo@praticos.com.br"
    private let demoPassword = "Demo@2024!"

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    func testTakeScreenshots() {
        print("🚀 Starting screenshot capture...")
        sleep(5)

        // Debug: what's on screen?
        debugScreen()

        // Check if already logged in by looking for home screen elements
        let isLoggedIn = checkIfLoggedIn()
        print("📍 Logged in check: \(isLoggedIn)")

        if isLoggedIn {
            print("📱 Already logged in - logging out first...")
            logout()
            sleep(3)
        }

        print("📱 On login screen")
        snapshot("00_Login")

        // Perform login
        if login() {
            print("✅ Login successful")
            sleep(3)
            captureScreens()
        } else {
            print("❌ Login failed")
            snapshot("99_LoginFailed")
        }
    }

    // MARK: - Debug

    private func debugScreen() {
        print("🔍 DEBUG - Buttons(\(app.buttons.count)): \(app.buttons.allElementsBoundByIndex.prefix(6).map { $0.label })")
        print("🔍 DEBUG - Texts(\(app.staticTexts.count)): \(app.staticTexts.allElementsBoundByIndex.prefix(5).map { $0.label })")
        print("🔍 DEBUG - TabBars: \(app.tabBars.count), Cells: \(app.cells.count)")
    }

    // MARK: - Check Login State

    private func checkIfLoggedIn() -> Bool {
        // Check for home screen elements (Flutter doesn't expose tabBars/cells natively)
        let homeElements = [
            app.buttons["Filtrar"],
            app.buttons["Nova OS"],
            app.buttons["Painel Financeiro"],
            app.staticTexts["Clientes"],
            app.staticTexts["Mais"]
        ]

        for element in homeElements {
            if element.exists {
                print("📍 Found home element: '\(element.label)'")
                return true
            }
        }

        return false
    }

    // MARK: - Logout

    private func logout() {
        print("🚪 Logging out...")

        // Tap "Mais" tab (Settings)
        let maisTab = app.staticTexts["Mais"]
        if maisTab.exists {
            maisTab.tap()
            sleep(2)
            print("📍 Tapped 'Mais' tab")
        }

        // Debug what's on settings screen
        print("🔍 Settings texts: \(app.staticTexts.allElementsBoundByIndex.prefix(10).map { $0.label })")
        print("🔍 Settings buttons: \(app.buttons.allElementsBoundByIndex.prefix(10).map { $0.label })")

        // Scroll down to find "Sair" (it's usually at the bottom)
        app.swipeUp()
        sleep(1)
        print("🔍 After scroll texts: \(app.staticTexts.allElementsBoundByIndex.prefix(10).map { $0.label })")

        // Find and tap "Sair" - look for text containing "Sair"
        var foundSair = false
        for text in app.staticTexts.allElementsBoundByIndex {
            if text.label.contains("Sair") {
                text.tap()
                print("📍 Tapped 'Sair' text")
                foundSair = true
                break
            }
        }

        if !foundSair {
            for btn in app.buttons.allElementsBoundByIndex {
                if btn.label.contains("Sair") {
                    btn.tap()
                    print("📍 Tapped 'Sair' button")
                    foundSair = true
                    break
                }
            }
        }

        if !foundSair {
            print("❌ Could not find 'Sair'")
            return
        }

        sleep(1)

        // Confirm logout if there's an alert/action sheet
        sleep(1)
        print("🔍 Looking for confirmation...")
        print("🔍 Alerts: \(app.alerts.count), Sheets: \(app.sheets.count)")

        // Try alert first
        if app.alerts.buttons["Sair"].exists {
            app.alerts.buttons["Sair"].tap()
            print("📍 Confirmed in alert")
        }
        // Try action sheet
        else if app.sheets.buttons["Sair"].exists {
            app.sheets.buttons["Sair"].tap()
            print("📍 Confirmed in sheet")
        }
        // Try any button with Sair
        else {
            for btn in app.buttons.allElementsBoundByIndex {
                if btn.label == "Sair" && btn.isHittable {
                    btn.tap()
                    print("📍 Tapped confirmation button")
                    break
                }
            }
        }

        sleep(3)

        // Verify we're logged out
        if app.buttons["Entrar com email"].exists || app.staticTexts["Entrar com email"].exists ||
           app.staticTexts["Bem-vindo ao PraticOS"].exists {
            print("✅ Logged out successfully")
        } else {
            print("⚠️ Logout may not have completed")
            debugScreen()
        }
    }

    // MARK: - Login

    private func login() -> Bool {
        print("🔑 Starting login...")

        // Tap "Entrar com email" - it's a CupertinoButton
        // Try button first, then staticText
        var emailLoginElement: XCUIElement?

        let emailButton = app.buttons["Entrar com email"]
        let emailText = app.staticTexts["Entrar com email"]

        if emailButton.waitForExistence(timeout: 3) {
            emailLoginElement = emailButton
            print("📍 Found as button")
        } else if emailText.waitForExistence(timeout: 3) {
            emailLoginElement = emailText
            print("📍 Found as staticText")
        }

        guard let element = emailLoginElement else {
            print("❌ 'Entrar com email' not found (tried button and staticText)")
            // Debug: list all buttons
            print("📋 Available buttons:")
            for btn in app.buttons.allElementsBoundByIndex.prefix(10) {
                print("   - '\(btn.label)'")
            }
            return false
        }

        element.tap()
        print("✅ Tapped 'Entrar com email'")
        sleep(2)

        // Get all text fields (Flutter exposes both email and password as textFields)
        let fields = app.textFields.allElementsBoundByIndex
        let secureFields = app.secureTextFields.allElementsBoundByIndex
        print("📝 Found \(fields.count) textFields, \(secureFields.count) secureTextFields")

        guard fields.count >= 1 else {
            print("❌ No text fields found")
            return false
        }

        // Enter email
        print("📧 Entering email...")
        let emailField = fields[0]
        emailField.tap()
        sleep(1)
        emailField.typeText(demoEmail)
        print("✅ Email entered")

        // Move to password using keyboard "Next" or tap the field
        print("🔒 Entering password...")
        sleep(1)

        // Try tapping Next on keyboard first
        let nextKey = app.keyboards.buttons["Next"]
        if nextKey.exists {
            nextKey.tap()
            print("📍 Tapped Next key")
            sleep(1)
        } else {
            // Tap password field directly
            if fields.count >= 2 {
                fields[1].tap()
                print("📍 Tapped password field")
                sleep(1)
            } else if secureFields.count >= 1 {
                secureFields[0].tap()
                print("📍 Tapped secure field")
                sleep(1)
            } else {
                print("❌ No password field found")
                return false
            }
        }

        // Type password
        app.typeText(demoPassword)
        print("✅ Password entered")

        // Dismiss keyboard and tap Entrar
        print("🔘 Tapping Entrar...")

        // Debug buttons available
        print("🔍 Buttons after password: \(app.buttons.allElementsBoundByIndex.prefix(6).map { $0.label })")

        // Try to dismiss keyboard first
        if app.keyboards.count > 0 {
            app.tap()
            sleep(1)
        }

        let entrarButton = app.buttons["Entrar"]
        if entrarButton.waitForExistence(timeout: 3) && entrarButton.isHittable {
            entrarButton.tap()
            print("✅ Tapped Entrar button")
        } else if app.staticTexts["Entrar"].exists {
            app.staticTexts["Entrar"].tap()
            print("✅ Tapped Entrar text")
        } else {
            print("⚠️ Entrar not found, trying to submit via keyboard")
            // Try pressing Return on keyboard
            if app.keyboards.buttons["Return"].exists {
                app.keyboards.buttons["Return"].tap()
            } else if app.keyboards.buttons["Go"].exists {
                app.keyboards.buttons["Go"].tap()
            }
        }

        // Wait for home screen (check for home elements)
        print("⏳ Waiting for home screen...")
        sleep(5)

        // Debug what's on screen
        debugScreen()

        let success = app.buttons["Filtrar"].exists ||
                      app.buttons["Nova OS"].exists ||
                      app.staticTexts["Clientes"].exists
        print(success ? "✅ Home screen loaded" : "❌ Home screen timeout")
        return success
    }

    // MARK: - Capture Screens

    private func captureScreens() {
        print("📸 Capturing screens...")

        // 1. Home
        print("📸 [1/6] Home")
        snapshot("01_Home")

        // 2. Order Detail - tap first order in list
        print("📸 [2/6] Order Detail")
        sleep(2)

        let listY = app.frame.height * 0.35
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: listY)).tap()
        sleep(3)
        snapshot("02_OrderDetail")

        // Go back to home
        goToHome()

        // 3. Dashboard
        print("📸 [3/6] Dashboard")
        if app.buttons["Painel Financeiro"].waitForExistence(timeout: 3) {
            app.buttons["Painel Financeiro"].tap()
            sleep(3)
            snapshot("03_Dashboard")
            goToHome()
        } else {
            print("⚠️ Dashboard button not found")
        }

        // 4. Customers tab
        print("📸 [4/6] Customers")
        app.staticTexts["Clientes"].tap()
        sleep(3)
        snapshot("04_Customers")

        // 5. Customer Detail - tap first customer
        print("📸 [5/6] Customer Detail")
        let customerY = app.frame.height * 0.35
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: customerY)).tap()
        sleep(3)
        snapshot("05_CustomerDetail")

        // Go back to customers
        goBack()
        sleep(2)

        // 6. Settings tab
        print("📸 [6/6] Settings")
        app.staticTexts["Mais"].tap()
        sleep(3)
        snapshot("06_Settings")

        print("🏁 Done!")
    }

    private func goBack() {
        if app.buttons["Back"].exists {
            app.buttons["Back"].tap()
        } else {
            app.swipeRight()
        }
        sleep(1)
    }

    private func goToHome() {
        // Try Back button first
        goBack()
        sleep(1)

        // Then tap Início tab to ensure we're on home
        if app.staticTexts["Início"].exists {
            app.staticTexts["Início"].tap()
            sleep(2)
        }
    }
}
