//
//  NFCManager.swift
//  Block
//
//  Created by Amit Sankaran on 1/7/26.
//

import Foundation
import CoreNFC
import Combine

class NFCManager: NSObject, ObservableObject {
    static let shared = NFCManager()
    
    @Published var isScanning = false
    @Published var lastScannedTag: String? = nil
    @Published var errorMessage: String? = nil
    
    private var session: NFCNDEFReaderSession?
    private let configStore = AppConfigurationStore.shared
    private let screenTimeManager = ScreenTimeManager.shared
    
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
    
    func handleBackgroundTag(_ identifier: String) {
        guard let registeredTag = configStore.registeredTagIdentifier else {
            return
        }
        
        if identifier == registeredTag {
            // Toggle blocking
            Task { @MainActor in
                screenTimeManager.toggleBlocking(for: configStore.selectedApps)
            }
        }
    }
    
    private func extractTagIdentifier(from message: NFCNDEFMessage) -> String? {
        // Extract identifier from NDEF message
        // Use the payload of the first record as the identifier
        guard let firstRecord = message.records.first else {
            return nil
        }
        
        // Convert payload to string
        if let payloadString = String(data: firstRecord.payload, encoding: .utf8) {
            return payloadString
        }
        
        // If not UTF-8, use base64 or hex representation
        return firstRecord.payload.base64EncodedString()
    }
}

extension NFCManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
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
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first else {
            return
        }
        
        guard let identifier = extractTagIdentifier(from: message) else {
            DispatchQueue.main.async {
                self.errorMessage = "Could not read tag identifier"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.lastScannedTag = identifier
            self.onTagScanned?(identifier)
            
            // If this is during registration, stop scanning
            if self.configStore.registeredTagIdentifier == nil {
                self.stopScanning()
            } else {
                // Handle toggle if tag matches registered tag
                self.handleBackgroundTag(identifier)
            }
        }
    }
}
