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
            print("❌ NFC not available on this device")
            return
        }

        isScanning = true
        errorMessage = nil
        print("🔵 Starting NFC scan session...")

        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
        session?.alertMessage = "Hold your iPhone near the NFC tag"
        session?.begin()
    }

    func stopScanning() {
        print("⏹️ Stopping NFC scan session")
        session?.invalidate()
        session = nil
        isScanning = false
    }

    func handleBackgroundTag(_ identifier: String) {
        guard let registeredTag = configStore.registeredTagIdentifier else {
            print("⚠️ No registered tag to compare")
            return
        }

        if identifier == registeredTag {
            print("✅ Tag matches - toggling blocking")
            screenTimeManager.toggleBlocking(for: configStore.selectedApps)
        } else {
            print("❌ Tag doesn't match")
            print("   Scanned: \(identifier)")
            print("   Registered: \(registeredTag)")
        }
    }

    // Debug function to simulate tag scan
    func simulateTagScan(withId identifier: String) {
        print("🧪 Simulating tag scan: \(identifier)")
        lastScannedTag = identifier
        onTagScanned?(identifier)

        if configStore.registeredTagIdentifier == nil {
            print("📝 No tag registered - registering: \(identifier)")
        } else {
            handleBackgroundTag(identifier)
        }
    }
}

extension NFCManager: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("🟢 NFC session became active")
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    print("🚫 User canceled NFC scan")
                    break
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.errorMessage = "Session timed out. Please try again."
                    print("⏱️ NFC session timeout")
                default:
                    self.errorMessage = "NFC e
                    rror: \(nfcError.localizedDescription)"
                    print("❌ NFC error: \(nfcError.localizedDescription)")
                }
            } else {
                self.errorMessage = "Error: \(error.localizedDescription)"
                print("❌ Error: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("📡 Detected \(tags.count) tag(s)")

        guard let tag = tags.first else {
            print("❌ No tags in array")
            return
        }

        session.connect(to: tag) { error in
            if let error = error {
                print("❌ Connection error: \(error.localizedDescription)")
                session.invalidate(errorMessage: "Connection failed. Please try again.")
                return
            }

            print("🔗 Connected to tag")

            // Extract tag identifier based on tag type
            var identifier: String?

            switch tag {
            case .iso7816(let iso7816Tag):
                identifier = iso7816Tag.identifier.map { String(format: "%02hhx", $0) }.joined()
                print("🏷️ ISO7816 tag ID: \(identifier ?? "nil")")

            case .feliCa(let feliCaTag):
                identifier = feliCaTag.currentIDm.map { String(format: "%02hhx", $0) }.joined()
                print("🏷️ FeliCa tag ID: \(identifier ?? "nil")")

            case .iso15693(let iso15693Tag):
                identifier = iso15693Tag.identifier.map { String(format: "%02hhx", $0) }.joined()
                print("🏷️ ISO15693 tag ID: \(identifier ?? "nil")")

            case .miFare(let miFareTag):
                identifier = miFareTag.identifier.map { String(format: "%02hhx", $0) }.joined()
                print("🏷️ MiFare tag ID: \(identifier ?? "nil")")

            @unknown default:
                print("❓ Unknown tag type")
                session.invalidate(errorMessage: "Unsupported tag type.")
                return
            }

            guard let tagId = identifier else {
                print("❌ Could not extract tag identifier")
                session.invalidate(errorMessage: "Could not read tag.")
                return
            }

            print("✅ Successfully read tag: \(tagId)")
            session.alertMessage = "Tag detected!"
            session.invalidate()

            Task { @MainActor in
                self.lastScannedTag = tagId
                self.onTagScanned?(tagId)

                if self.configStore.registeredTagIdentifier == nil {
                    print("📝 Registering new tag")
                    self.stopScanning()
                } else {
                    print("🔄 Handling tag for toggle")
                    self.handleBackgroundTag(tagId)
                    self.stopScanning()
                }
            }
        }
    }
}
