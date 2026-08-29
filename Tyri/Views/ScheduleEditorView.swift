//
//  ScheduleEditorView.swift
//  Tyri
//

import SwiftUI

struct ScheduleEditorView: View {
    @Binding var schedule: BlockingSchedule?
    @Environment(\.dismiss) private var dismiss

    @State private var enabled: Bool = false
    @State private var startDate: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var endDate: Date = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    init(schedule: Binding<BlockingSchedule?>) {
        self._schedule = schedule
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable Schedule", isOn: $enabled)
                    .tint(ArtNouveauTheme.primary)
            }

            if enabled {
                Section("Time") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endDate, displayedComponents: .hourAndMinute)

                    if currentSchedule.crossesMidnight {
                        Label("This block continues past midnight.", systemImage: "moon.stars")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(ArtNouveauTheme.secondaryLabel)
                    }
                }

                Section("Days") {
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            WeekdayToggle(
                                day: day,
                                isOn: weekdays.contains(day)
                            ) {
                                if weekdays.contains(day) {
                                    weekdays.remove(day)
                                } else {
                                    weekdays.insert(day)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    commit()
                    dismiss()
                }
                .foregroundColor(ArtNouveauTheme.primary)
            }
        }
        .onAppear { hydrate() }
    }

    private func hydrate() {
        if let s = schedule {
            enabled = true
            startDate = Calendar.current.date(from: DateComponents(hour: s.startHour, minute: s.startMinute)) ?? startDate
            endDate = Calendar.current.date(from: DateComponents(hour: s.endHour, minute: s.endMinute)) ?? endDate
            weekdays = s.weekdays
        } else {
            enabled = false
        }
    }

    private var currentSchedule: BlockingSchedule {
        let startComps = Calendar.current.dateComponents([.hour, .minute], from: startDate)
        let endComps = Calendar.current.dateComponents([.hour, .minute], from: endDate)
        return BlockingSchedule(
            startHour: startComps.hour ?? 9,
            startMinute: startComps.minute ?? 0,
            endHour: endComps.hour ?? 17,
            endMinute: endComps.minute ?? 0,
            weekdays: weekdays
        )
    }

    private func commit() {
        if enabled && !weekdays.isEmpty {
            schedule = currentSchedule
        } else {
            schedule = nil
        }
    }
}

private struct WeekdayToggle: View {
    let day: Int
    let isOn: Bool
    let onTap: () -> Void

    private var label: String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let index = day - 1
        return (index >= 0 && index < symbols.count) ? symbols[index] : "?"
    }

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .foregroundColor(isOn ? .white : ArtNouveauTheme.label)
                .frame(width: 36, height: 36)
                .background(
                    Group {
                        if isOn {
                            Circle().fill(ArtNouveauTheme.primaryGradient)
                        } else {
                            Circle().fill(ArtNouveauTheme.secondaryBackground)
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(isOn ? Color.clear : ArtNouveauTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
