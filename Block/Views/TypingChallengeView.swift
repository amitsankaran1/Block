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
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(ArtNouveauTheme.warningLight)
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "keyboard.fill")
                                .font(.system(size: 50, weight: .semibold))
                                .foregroundColor(ArtNouveauTheme.warning)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .shadow(color: ArtNouveauTheme.warning.opacity(0.3), radius: 12, x: 0, y: 6)

                        VStack(spacing: 10) {
                            Text("Emergency Override")
                                .font(.system(.title, design: .default).weight(.bold))
                                .foregroundColor(ArtNouveauTheme.label)

                            Text("Type the passage below exactly to disable blocking without your tag.")
                                .font(.system(.subheadline, design: .default).weight(.medium))
                                .foregroundColor(ArtNouveauTheme.secondaryLabel)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 32)

                    // Challenge text to type
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Type this passage:")
                            .font(.system(.caption, design: .default).weight(.bold))
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                            .textCase(.uppercase)
                            .tracking(1.0)

                        ArtNouveauCard(shadow: ArtNouveauTheme.shadowSmall) {
                            Text(challengeText)
                                .font(.system(.body, design: .default))
                                .foregroundColor(ArtNouveauTheme.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Input area
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Type here:")
                                .font(.system(.headline, design: .default).weight(.bold))
                                .foregroundColor(ArtNouveauTheme.label)

                            Spacer()

                            Image(systemName: "keyboard")
                                .foregroundColor(ArtNouveauTheme.primary)
                                .font(.system(size: 20, weight: .semibold))
                        }

                        ZStack(alignment: .topLeading) {
                            // Placeholder text
                            if userInput.isEmpty {
                                Text("Start typing the passage above...")
                                    .font(.system(.body, design: .default))
                                    .foregroundColor(ArtNouveauTheme.tertiaryLabel)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 18)
                            }

                            TextEditor(text: $userInput)
                                .font(.system(.body, design: .default))
                                .padding(14)
                                .frame(height: 140)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .onChange(of: userInput) { _ in
                                    showError = false
                                    checkIfCorrect()
                                }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ArtNouveauTheme.secondaryBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    showError 
                                        ? ArtNouveauTheme.error 
                                        : (userInput.isEmpty ? ArtNouveauTheme.border : ArtNouveauTheme.primary), 
                                    lineWidth: showError ? 2.5 : 2
                                )
                        )
                        .shadow(
                            color: showError 
                                ? ArtNouveauTheme.error.opacity(0.2) 
                                : (userInput.isEmpty ? Color.clear : ArtNouveauTheme.primary.opacity(0.15)),
                            radius: showError ? 8 : 6,
                            x: 0,
                            y: 3
                        )

                        // Character count and status
                        HStack {
                            Text("\(userInput.count) / \(challengeText.count) characters")
                                .font(.system(.caption, design: .default).weight(.medium))
                                .foregroundColor(ArtNouveauTheme.secondaryLabel)

                            Spacer()

                            if isCorrect {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(ArtNouveauTheme.success)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Match!")
                                        .font(.system(.caption, design: .default).weight(.bold))
                                        .foregroundColor(ArtNouveauTheme.success)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(ArtNouveauTheme.successLight)
                                .cornerRadius(8)
                            }
                        }

                        if showError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(ArtNouveauTheme.error)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Text doesn't match. Please type it exactly as shown above.")
                                    .font(.system(.caption, design: .default).weight(.medium))
                                    .foregroundColor(ArtNouveauTheme.error)
                            }
                            .padding(12)
                            .background(ArtNouveauTheme.errorLight)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Submit button
                    Button {
                        attemptSubmit()
                    } label: {
                        HStack(spacing: 10) {
                            if isCorrect {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            Text(isCorrect ? "Disable Blocking" : "Check Answer")
                                .font(.system(.headline, design: .default).weight(.bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            isCorrect 
                                ? ArtNouveauTheme.successGradient 
                                : ArtNouveauTheme.primaryGradient
                        )
                        .cornerRadius(16)
                        .shadow(
                            color: (isCorrect ? ArtNouveauTheme.success : ArtNouveauTheme.primary).opacity(0.4),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                    }
                    .disabled(userInput.isEmpty || !isCorrect)
                    .opacity((userInput.isEmpty || !isCorrect) ? 0.6 : 1.0)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        ArtNouveauTheme.background,
                        ArtNouveauTheme.secondaryBackground.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Typing Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(ArtNouveauTheme.primary)
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
            // Emergency override — clear every active block.
            screenTimeManager.disableAllBlocks()
            isPresented = false
        } else {
            showError = true
        }
    }
}
