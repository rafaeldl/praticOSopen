//
//  ShareViewController.swift
//  ShareExtension
//
//  "Compartilhar -> PraticOS": receives photos, PDFs and contacts from other
//  apps. receive_sharing_intent copies the files to the App Group container and
//  opens the app, which asks "Em qual OS?" or, for a contact, opens the new
//  customer form (see lib/services/receive_share_service.dart).
//

import UIKit
import receive_sharing_intent

class ShareViewController: RSIShareViewController {
    private static let pdfType = "com.adobe.pdf"
    private static let vcardType = "public.vcard"
    private static let fileUrlType = "public.file-url"

    private var attachmentsPrepared = false

    // Some apps (Mail, Safari, WhatsApp) share a PDF only as "com.adobe.pdf"
    // data, without a file URL. The plugin only reads files through
    // "public.file-url", so those PDFs would be dropped. Before handing the
    // attachments to the plugin, write such PDFs to a temporary file and
    // expose them as a file URL.
    //
    // Contacts (.vcf) always go through the same path, even with a file URL:
    // "public.vcard" conforms to "public.text", so the plugin would load the
    // card as text and drop it.
    override func viewDidAppear(_ animated: Bool) {
        if attachmentsPrepared {
            super.viewDidAppear(animated)
            return
        }
        attachmentsPrepared = true
        prepareDataAttachments { [weak self] in
            self?.continueWithPlugin(animated)
        }
    }

    private func continueWithPlugin(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    private func prepareDataAttachments(completion: @escaping () -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments, !providers.isEmpty else {
            completion()
            return
        }

        var result = providers
        let lock = NSLock()
        let group = DispatchGroup()

        for (index, provider) in providers.enumerated() {
            let isContact = provider.hasItemConformingToTypeIdentifier(Self.vcardType)
            let isPdfData = provider.hasItemConformingToTypeIdentifier(Self.pdfType)
                && !provider.hasItemConformingToTypeIdentifier(Self.fileUrlType)
            guard isContact || isPdfData else {
                continue
            }
            group.enter()
            let suggestedName = provider.suggestedName
            let type = isContact ? Self.vcardType : Self.pdfType
            provider.loadItem(forTypeIdentifier: type, options: nil) { data, _ in
                defer { group.leave() }
                guard let url = Self.writeTemporaryFile(
                    data,
                    suggestedName: suggestedName,
                    fallbackName: isContact ? "Contato" : "Documento",
                    fileExtension: isContact ? "vcf" : "pdf"
                ) else {
                    return
                }
                lock.lock()
                result[index] = NSItemProvider(item: url as NSURL, typeIdentifier: Self.fileUrlType)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            item.attachments = result
            completion()
        }
    }

    private static func writeTemporaryFile(
        _ data: NSSecureCoding?,
        suggestedName: String?,
        fallbackName: String,
        fileExtension: String
    ) -> URL? {
        var name = (suggestedName ?? "").replacingOccurrences(of: "/", with: "-")
        if name.isEmpty { name = fallbackName }
        if !name.lowercased().hasSuffix(".\(fileExtension)") { name += ".\(fileExtension)" }

        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = directory.appendingPathComponent(name)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            if let url = data as? URL {
                try fileManager.copyItem(at: url, to: destination)
            } else if let bytes = data as? Data {
                try bytes.write(to: destination)
            } else if let text = data as? String {
                try text.write(to: destination, atomically: true, encoding: .utf8)
            } else {
                return nil
            }
            return destination
        } catch {
            return nil
        }
    }
}
