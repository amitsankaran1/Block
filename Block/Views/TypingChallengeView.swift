//
//  TypingChallengeView.swift
//  Block
//
//  Created by Amit Sankaran on 1/12/26.
//

import SwiftUI

struct TypingChallengeView: View {
    @Binding var isPresented: Bool
    @StateObject private var configStore = AppConfigurationStore.shared
    @StateObject private var screenTimeManager = ScreenTimeManager.shared

    @State private var userInput = ""
    @State private var isCorrect = false
    @State private var showError = false

    private let challengeText = """
I am choosing to use my time wisely. These apps distract me from my goals and waste my potential. I will stay focused on what matters most to me.
"""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(ArtNouveauTheme.warning)
                            .symbolRenderingMode(.hierarchical)

                        Text("Emergency Override")
                            .font(.title2.bold())

                        Text("Type the passage below exactly to disable blocking without your NFC tag.")
                            .font(.subheadline)
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 20)

                    // Challenge text to type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type this passage:")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                            .textCase(.uppercase)

                        Text(challengeText)
                            .font(.body)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ArtNouveauTheme.primary.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)

                    // Input area
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Type here:")
                                .font(.headline)
                                .foregroundColor(ArtNouveauTheme.label)

                            Spacer()

                            Image(systemName: "keyboard")
                                .foregroundColor(ArtNouveauTheme.primary)
                                .font(.title3)
                        }

                        ZStack(alignment: .topLeading) {
                            // Placeholder text
                            if userInput.isEmpty {
                                Text("Start typing the passage above...")
                                    .font(.body)
                                    .foregroundColor(ArtNouveauTheme.tertiaryLabel)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                            }

                            TextEditor(text: $userInput)
                                .font(.body)
                                .padding(12)
                                .frame(height: 120)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .onChange(of: userInput) { _ in
                                    showError = false
                                    checkIfCorrect()
                                }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ArtNouveauTheme.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(showError ? ArtNouveauTheme.error : (userInput.isEmpty ? ArtNouveauTheme.border : ArtNouveauTheme.primary), lineWidth: showError ? 2 : 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)

                        // Character count
                        HStack {
                            Text("\(userInput.count) / \(challengeText.count) characters")
                                .font(.caption)
                                .foregroundColor(ArtNouveauTheme.secondaryLabel)

                            Spacer()

                            if isCorrect {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(ArtNouveauTheme.success)
                                    Text("Match!")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(ArtNouveauTheme.success)
                                }
                            }
                        }

                        if showError {
                            Text("Text doesn't match. Please type it exactly as shown above.")
                                .font(.caption)
                                .foregroundColor(ArtNouveauTheme.error)
                        }
                    }
                    .padding(.horizontal, 32)

                    // Submit button
                    Button {
                        attemptSubmit()
                    } label: {
                        Text(isCorrect ? "Disable Blocking" : "Check Answer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isCorrect ? ArtNouveauTheme.success : ArtNouveauTheme.primary)
                            .cornerRadius(12)
                    }
                    .disabled(userInput.isEmpty)
                    .opacity(userInput.isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Typing Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func checkIfCorrect() {
        // Allow small differences (case insensitive, ignore extra whitespace)
        let normalizedChallenge = challengeText.lowercased().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let normalizedInput = userInput.lowercased().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)

        isCorrect = normalizedInput == normalizedChallenge
    }

    private func attemptSubmit() {
        checkIfCorrect()

        if isCorrect {
            // Disable blocking
            screenTimeManager.disableBlocking()
            isPresented = false
        } else {
            showError = true
        }
    }
}
