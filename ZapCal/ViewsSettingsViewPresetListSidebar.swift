//
//  PresetListSidebar.swift
//  ZapCal
//
//  Shared preset list sidebar used by both PresetsSettingsView and PreAlertPresetsSettingsView.
//

import SwiftUI
import EventKit
import UniformTypeIdentifiers

struct PresetListSidebar: View {
    struct PresetItem: Identifiable {
        let name: String
        let isBuiltIn: Bool
        var id: String { name }
    }

    let presets: [PresetItem]
    @Binding var selectedPresetName: String
    let defaultPresetName: String
    let assignKind: AssignCalendarsSheet.Kind
    let calendars: [EKCalendar]
    let reminderLists: [EKCalendar]

    let uniqueName: (String) -> String
    let validateName: (String) -> Bool
    let onDuplicate: (_ from: String, _ newName: String) -> Void
    let onRename: (_ from: String, _ newName: String) -> Void
    let onDelete: (_ name: String) -> Void
    let onSelectionChange: (_ name: String) -> Void

    @ObservedObject private var themeService = ThemeService.shared

    @State private var showingDuplicateDialog = false
    @State private var duplicateName = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingRenameDialog = false
    @State private var renameTarget = ""
    @State private var assignCalendarPresetName: String? = nil
    @State private var assignReminderPresetName: String? = nil

    private var builtInPresets: [PresetItem] { presets.filter(\.isBuiltIn) }
    private var customPresets: [PresetItem] { presets.filter { !$0.isBuiltIn } }
    private var isBuiltIn: Bool { presets.first(where: { $0.name == selectedPresetName })?.isBuiltIn ?? true }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedPresetName) {
                Section("Built-in Themes") {
                    ForEach(builtInPresets) { preset in
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(preset.name)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .tag(preset.name)
                        .contextMenu {
                            Button("Copy") {
                                duplicateName = uniqueName(preset.name)
                                selectedPresetName = preset.name
                                showingDuplicateDialog = true
                            }
                            if !calendars.isEmpty {
                                Button("Assign to Calendar...") {
                                    assignCalendarPresetName = preset.name
                                }
                            }
                            if !reminderLists.isEmpty {
                                Button("Assign to Reminder List...") {
                                    assignReminderPresetName = preset.name
                                }
                            }
                        }
                    }
                }
                Section("Custom Themes") {
                    ForEach(customPresets) { preset in
                        HStack {
                            Text(preset.name)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .tag(preset.name)
                        .contextMenu {
                            Button("Copy") {
                                duplicateName = uniqueName(preset.name)
                                selectedPresetName = preset.name
                                showingDuplicateDialog = true
                            }
                            Button("Rename") {
                                renameTarget = preset.name
                                showingRenameDialog = true
                            }
                            if !calendars.isEmpty {
                                Button("Assign to Calendar...") {
                                    assignCalendarPresetName = preset.name
                                }
                            }
                            if !reminderLists.isEmpty {
                                Button("Assign to Reminder List...") {
                                    assignReminderPresetName = preset.name
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                selectedPresetName = preset.name
                                showingDeleteConfirmation = true
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedPresetName) { newValue in
                onSelectionChange(newValue)
            }

            Divider()

            HStack(spacing: 8) {
                Button("Copy") {
                    duplicateName = uniqueName(selectedPresetName)
                    showingDuplicateDialog = true
                }
                .frame(maxWidth: .infinity)

                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
                .disabled(isBuiltIn)
            }
            .padding(8)
        }
        .frame(width: 180)
        .sheet(isPresented: $showingDuplicateDialog) {
            PresetNameSheet(
                title: "Copy Theme",
                message: "Enter a name for the new theme.",
                actionLabel: "Copy",
                initialName: duplicateName,
                validate: validateName,
                onSubmit: { name in
                    onDuplicate(selectedPresetName, name)
                    selectedPresetName = name
                }
            )
        }
        .alert("Delete Theme?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete(selectedPresetName)
                selectedPresetName = defaultPresetName
            }
        } message: {
            Text("This will permanently delete \"\(selectedPresetName)\" and reset any calendars using it.")
        }
        .sheet(isPresented: $showingRenameDialog) {
            PresetNameSheet(
                title: "Rename Theme",
                message: "Enter a new name for \"\(renameTarget)\".",
                actionLabel: "Rename",
                initialName: renameTarget,
                validate: { $0 == renameTarget || validateName($0) },
                onSubmit: { name in
                    onRename(renameTarget, name)
                    selectedPresetName = name
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { assignCalendarPresetName != nil },
            set: { if !$0 { assignCalendarPresetName = nil } }
        )) {
            if let presetName = assignCalendarPresetName {
                AssignCalendarsSheet(
                    presetName: presetName,
                    calendars: calendars,
                    themeService: themeService,
                    kind: assignKind
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { assignReminderPresetName != nil },
            set: { if !$0 { assignReminderPresetName = nil } }
        )) {
            if let presetName = assignReminderPresetName {
                AssignCalendarsSheet(
                    presetName: presetName,
                    calendars: reminderLists,
                    themeService: themeService,
                    kind: assignKind,
                    itemLabel: "Reminder Lists"
                )
            }
        }
    }
}

// MARK: - Save / Revert Footer

struct PresetSaveRevertFooter: View {
    let isEditable: Bool
    @Binding var showingSavedConfirmation: Bool
    let onRevert: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Revert Changes") { onRevert() }

            Spacer()

            if isEditable {
                Button(showingSavedConfirmation ? "Saved!" : "Update Theme") {
                    onSave()
                    showingSavedConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingSavedConfirmation = false
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Built-in theme (read-only)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Shared Helpers

func showPresetImagePicker(onSelect: (String) -> Void) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.png, .jpeg, .webP]

    if panel.runModal() == .OK, let url = panel.url {
        if let data = try? Data(contentsOf: url) {
            onSelect(ImageStore.save(data))
        }
    }
}
