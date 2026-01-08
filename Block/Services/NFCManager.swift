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

    private var session: NFCNDEFReaderSession?

    var onTagScanned: ((String) -> Void)?

    override private init() {
        super.init()
    }

    func startScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "NFC reading is not available on this device"
            return
        }

        isScanning = true
        errorMessage = nil

        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the NFC tag"
        session?.begin()
    }

    func stopScanning() {
        session?.invalidate()
        session = nil
        isScanning = false
    }

    func handleBackgroundTag(_ identifier: String, configStore: AppConfigurationStore, screenTimeManager: ScreenTimeManager) {
        guard let registeredTag = configStore.registeredTagIdentifier else {
            return
        }

        if identifier == registeredTag {
            // Toggle blocking
            screenTimeManager.toggleBlocking(for: configStore.selectedApps)
        }
    }

    private func extractTagIdentifier(from message: NFCNDEFMessage) -> String? {
        // Use the message's type and identifier for a more reliable unique identifier
        // Combine all record payloads to create a consistent identifier
        let payloads = message.records.map { $0.payload }
        let combinedData = payloads.reduce(Data()) { $0 + $1 }

        // If the combined data is small and UTF-8 compatible, use it
        if combinedData.count < 256, let textIdentifier = String(data: combinedData, encoding: .utf8), !textIdentifier.isEmpty {
            return textIdentifier
        }

        // Otherwise use hex representation for reliability
        return combinedData.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension NFCManager: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User canceled - this is fine
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

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first else {
            return
        }

        guard let identifier = extractTagIdentifier(from: message) else {
            Task { @MainActor in
                self.errorMessage = "Could not read tag identifier"
            }
            return
        }

        Task { @MainActor in
            self.lastScannedTag = identifier
            self.onTagScanned?(identifier)

            // Stop scanning after successful tag read
            self.stopScanning()
        }
    }
}
