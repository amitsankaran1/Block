//
//  NFCManager.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import Foundation
import CoreNFC
import Combine

@MainActor
class NFCManager: NSObject, ObservableObject {
    static let shared = NFCManager()

    @Published var isScanning = false
    @Published var lastScannedTag: String? = nil
    @Published var errorMessage: String? = nil

    private var session: NFCTagReaderSession?
    private let configStore = AppConfigurationStore.shared
    private let screenTimeManager = ScreenTimeManager.shared

    var onTagScanned: ((String) -> Void)?

    override private init() {
        super.init()
    }

    func startScanning() {
        guard NFCTagReaderSession.readingAvailable else {
            errorMessage = "NFC reading is not available on this device"
            return
        }

        isScanning = true
        errorMessage = nil

        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
        session?.alertMessage = "Hold your iPhone near the NFC tag"
        session?.begin()
    }

    func stopScanning() {
        session?.invalidate()
        session = nil
        isScanning = false
    }

    func handleBackgroundTag(_ identifier: String) {
        guard let registeredTag = configStore.registeredTagIdentifier else {
            return
        }

        if identifier == registeredTag {
            screenTimeManager.toggleBlocking(for: configStore.selectedApps)
        }
    }

    func simulateTagScan(withId identifier: String) {
        lastScannedTag = identifier

        // Check registration status BEFORE calling callback
        let wasRegistered = configStore.registeredTagIdentifier != nil

        onTagScanned?(identifier)

        if wasRegistered {
            handleBackgroundTag(identifier)
        }
    }
}

extension NFCManager: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    break
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.errorMessage = "Session timed out. Please try again."
                default:
                    self.errorMessage = "NFC error: \(nfcError.localizedDescription)"
                }
            } else {
                self.errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            return
        }

        session.connect(to: tag) { error in
            if error != nil {
                session.invalidate(errorMessage: "Connection failed. Please try again.")
                return
            }

            // Extract tag identifier based on tag type
            var identifier: String?

            switch tag {
            case .iso7816(let iso7816Tag):
                identifier = iso7816Tag.identifier.map { String(format: "%02hhx", $0) }.joined()

            case .feliCa(let feliCaTag):
                identifier = feliCaTag.currentIDm.map { String(format: "%02hhx", $0) }.joined()

            case .iso15693(let iso15693Tag):
                identifier = iso15693Tag.identifier.map { String(format: "%02hhx", $0) }.joined()

            case .miFare(let miFareTag):
                identifier = miFareTag.identifier.map { String(format: "%02hhx", $0) }.joined()

            @unknown default:
                session.invalidate(errorMessage: "Unsupported tag type.")
                return
            }

            guard let tagId = identifier else {
                session.invalidate(errorMessage: "Could not read tag.")
                return
            }

            // Invalidate immediately without showing alert message for faster dismissal
            session.invalidate()

            Task { @MainActor in
                self.lastScannedTag = tagId

                // Call the callback - ContentView will handle toggling if tag is registered
                self.onTagScanned?(tagId)
                
                self.stopScanning()
            }
        }
    }
}
