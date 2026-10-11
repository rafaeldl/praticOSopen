//
//  ShareViewController.swift
//  ShareExtension
//
//  "Compartilhar -> PraticOS": receives photos and PDFs from other apps.
//  receive_sharing_intent copies the files to the App Group container and
//  opens the app, which asks "Em qual OS?" (see lib/services/receive_share_service.dart).
//

import UIKit
import receive_sharing_intent

class ShareViewController: RSIShareViewController {
    private static let pdfType = "com.adobe.pdf"
    private static let fileUrlType = "public.file-url"

    private var attachmentsPrepared = false

    // Some apps (Mail, Safari, WhatsApp) share a PDF only as "com.adobe.pdf"
    // data, without a file URL. The plugin only reads files through
    // "public.file-url", so those PDFs would be dropped. Before handing the
    // attachments to the plugin, write such PDFs to a temporary file and
    // expose them as a file URL.
    override func viewDidAppear(_ animated: Bool) {
        if attachmentsPrepared {
            super.viewDidAppear(animated)
            return
        }
        attachmentsPrepared = true
        preparePdfAttachments { [weak self] in
            self?.continueWithPlugin(animated)
        }
    }

    private func continueWithPlugin(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    private func preparePdfAttachments(completion: @escaping () -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments, !providers.isEmpty else {
            completion()
            return
        }

        var result = providers
        let lock = NSLock()
        let group = DispatchGroup()

        for (index, provider) in providers.enumerated() {
            guard provider.hasItemConformingToTypeIdentifier(Self.pdfType),
                  !provider.hasItemConformingToTypeIdentifier(Self.fileUrlType) else {
                continue
            }
            group.enter()
            let suggestedName = provider.suggestedName
            provider.loadItem(forTypeIdentifier: Self.pdfType, options: nil) { data, _ in
                defer { group.leave() }
                guard let url = Self.writeTemporaryPdf(data, suggestedName: suggestedName) else {
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

    private static func writeTemporaryPdf(_ data: NSSecureCoding?, suggestedName: String?) -> URL? {
        var name = (suggestedName ?? "").replacingOccurrences(of: "/", with: "-")
        if name.isEmpty { name = "Documento" }
        if !name.lowercased().hasSuffix(".pdf") { name += ".pdf" }

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
            } else {
                return nil
            }
            return destination
        } catch {
            return nil
        }
    }
}
