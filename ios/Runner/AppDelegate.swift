import UIKit
import Flutter
import ContactsUI

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var contactPicker: ContactPicker?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let snapshotChannel = FlutterMethodChannel(name: "br.com.rafsoft.praticos/snapshot",
                                              binaryMessenger: controller.binaryMessenger)
    snapshotChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "isSnapshotMode") {
        result(ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT"))
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    let picker = ContactPicker(host: controller)
    contactPicker = picker
    FlutterMethodChannel(name: "br.com.rafsoft.praticos/contacts",
                         binaryMessenger: controller.binaryMessenger)
      .setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if (call.method == "pick") {
          picker.pick(result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// The system picker runs out of process and hands over only the contact the
// person chooses, so it needs no contacts permission.
private class ContactPicker: NSObject, CNContactPickerDelegate {
  private weak var host: UIViewController?
  private var pending: FlutterResult?

  init(host: UIViewController) {
    self.host = host
  }

  func pick(_ result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "Contact picker already open", details: nil))
      return
    }
    guard let host = host else {
      result(FlutterError(code: "unavailable", message: "No screen to present from", details: nil))
      return
    }
    pending = result
    let picker = CNContactPickerViewController()
    picker.delegate = self
    host.present(picker, animated: true)
  }

  func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    finish(nil)
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
    finish([
      "name": Self.name(of: contact),
      "phones": contact.isKeyAvailable(CNContactPhoneNumbersKey)
        ? contact.phoneNumbers.map { $0.value.stringValue } : [],
      "email": contact.isKeyAvailable(CNContactEmailAddressesKey)
        ? contact.emailAddresses.first.map { $0.value as String } as Any : NSNull(),
    ])
  }

  private func finish(_ value: Any?) {
    pending?(value)
    pending = nil
  }

  private static func name(of contact: CNContact) -> String {
    let parts = [CNContactGivenNameKey, CNContactMiddleNameKey, CNContactFamilyNameKey]
      .filter { contact.isKeyAvailable($0) }
      .compactMap { contact.value(forKey: $0) as? String }
      .filter { !$0.isEmpty }
    if !parts.isEmpty { return parts.joined(separator: " ") }
    return contact.isKeyAvailable(CNContactOrganizationNameKey) ? contact.organizationName : ""
  }
}
