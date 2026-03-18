//
//  PreAlertPresetsSettingsView.swift
//  Full Screen Calendar Reminder
//

import SwiftUI
import UniformTypeIdentifiers

struct PreAlertPresetsSettingsView: View {
    @ObservedObject var presetManager = PreAlertPresetManager.shared

    @State private var selectedPresetName: String = "Coral Paper"
    @State private var workingTheme: PreAlertTheme
    @State private var showingSavedConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDuplicateDialog = false
    @State private var duplicateName = ""

    init() {
        _workingTheme = State(initialValue: PreAlertPresetManager.shared.theme(named: "Coral Paper"))
    }

    var body: some View {
        HStack(spacing: 0) {
            presetList

            Divider()

            previewPane

            Divider()

            editorPane
        }
    }

    // MARK: - Preset List

    private var presetList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedPresetName) {
                Section("Built-in Presets") {
                    ForEach(presetManager.presets.filter { presetManager.isBuiltIn($0.name) }) { preset in
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(preset.name)
                                .lineLimit(1)
                        }
                        .contentShape(Rectangle())
                        .tag(preset.name)
                    }
                }
                Section("Custom Presets") {
                    ForEach(presetManager.presets.filter { !presetManager.isBuiltIn($0.name) }) { preset in
                        Text(preset.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .contentShape(Rectangle())
                            .tag(preset.name)
                    }
                }
            }
            .onChange(of: selectedPresetName) { newValue in
                loadPreset(named: newValue)
            }

            Divider()

            HStack(spacing: 8) {
                Button("Copy") {
                    duplicateName = presetManager.uniqueName(base: selectedPresetName)
                    showingDuplicateDialog = true
                }
                .frame(maxWidth: .infinity)

                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
                .disabled(presetManager.isBuiltIn(selectedPresetName))
            }
            .padding(8)
        }
        .frame(width: 180)
        .alert("Copy Preset", isPresented: $showingDuplicateDialog) {
            TextField("Name", text: $duplicateName)
            Button("Cancel", role: .cancel) { }
            Button("Copy") {
                let name = duplicateName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                presetManager.duplicatePreset(from: selectedPresetName, newName: name)
                selectedPresetName = name
            }
        } message: {
            Text("Enter a name for the new preset.")
        }
        .alert("Delete Preset?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                ThemeService.shared.clearPreAlertAssignments(for: selectedPresetName)
                presetManager.deletePreset(named: selectedPresetName)
                selectedPresetName = "Coral Paper"
            }
        } message: {
            Text("This will permanently delete \"\(selectedPresetName)\" and reset any calendars using it.")
        }
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        VStack(spacing: 0) {
            Spacer()

            PreAlertBannerView(
                title: "Team Standup",
                startDate: Date().addingTimeInterval(185),
                color: .blue,
                videoURL: URL(string: "https://example.com"),
                preAlertTheme: workingTheme,
                onDismiss: {},
                onJoin: { _ in },
                onDisableAlerts: {}
            )
            .frame(width: 460)
            .padding()

            Spacer()

            HStack(spacing: 12) {
                Button("Preview Banner") {
                    PreAlertManager.shared.showTestPreAlert(theme: workingTheme)
                }
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Editor Pane

    private var isEditable: Bool {
        presetManager.isEditable(selectedPresetName)
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Background")
                        .font(.headline)

                    Picker("Type", selection: $workingTheme.backgroundType) {
                        Text("Solid Color").tag(PreAlertTheme.BackgroundType.solidColor)
                        Text("Image").tag(PreAlertTheme.BackgroundType.image)
                    }
                    .pickerStyle(.segmented)

                    if workingTheme.backgroundType == .solidColor {
                        ColorPicker("Color", selection: Binding(
                            get: { workingTheme.backgroundColor.color },
                            set: { workingTheme.backgroundColor = CodableColor($0) }
                        ))

                        Slider(value: $workingTheme.backgroundOpacity, in: 0.5...1.0, step: 0.05) {
                            Text("Opacity: \(Int(workingTheme.backgroundOpacity * 100))%")
                        }
                    } else {
                        if let imageData = workingTheme.imageData,
                           let nsImage = NSImage(data: imageData) {
                            HStack {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 80)
                                    .cornerRadius(8)

                                Spacer()

                                Button("Remove") {
                                    workingTheme.imageData = nil
                                    workingTheme.backgroundType = .solidColor
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        Button("Choose Image") {
                            showImagePicker()
                        }

                        ColorPicker("Overlay Color", selection: Binding(
                            get: { workingTheme.overlayColor.color },
                            set: { workingTheme.overlayColor = CodableColor($0) }
                        ))

                        Slider(
                            value: $workingTheme.overlayOpacity,
                            in: 0.0...1.0,
                            step: 0.05
                        ) {
                            Text("Overlay Opacity: \(Int(workingTheme.overlayOpacity * 100))%")
                        }

                        Slider(
                            value: Binding(
                                get: { workingTheme.imageBlurRadius ?? 0.3 },
                                set: { workingTheme.imageBlurRadius = $0 }
                            ),
                            in: 0.0...1.0,
                            step: 0.05
                        ) {
                            Text("Blur: \(Int((workingTheme.imageBlurRadius ?? 0.3) * 100))%")
                        }
                    }

                    Divider()

                    Text("Colors")
                        .font(.headline)

                    Divider()

                    ColorPicker("Title", selection: Binding(
                        get: { workingTheme.titleColor.color },
                        set: { workingTheme.titleColor = CodableColor($0) }
                    ))

                    ColorPicker("Countdown", selection: Binding(
                        get: { workingTheme.countdownColor.color },
                        set: { workingTheme.countdownColor = CodableColor($0) }
                    ))

                    Divider()

                    Text("Dismiss Button")
                        .font(.subheadline.weight(.medium))

                    ColorPicker("Button Color", selection: Binding(
                        get: { workingTheme.dismissButtonColor.color },
                        set: { workingTheme.dismissButtonColor = CodableColor($0) }
                    ))

                    ColorPicker("Icon Color", selection: Binding(
                        get: { workingTheme.dismissIconColor.color },
                        set: { workingTheme.dismissIconColor = CodableColor($0) }
                    ))

                    ColorPicker("Progress Ring", selection: Binding(
                        get: { workingTheme.progressRingColor.color },
                        set: { workingTheme.progressRingColor = CodableColor($0) }
                    ))

                    Divider()

                    Text("Disable Button")
                        .font(.subheadline.weight(.medium))

                    ColorPicker("Text Color", selection: Binding(
                        get: { workingTheme.disableButtonTextColor.color },
                        set: { workingTheme.disableButtonTextColor = CodableColor($0) }
                    ))

                    ColorPicker("Background", selection: Binding(
                        get: { workingTheme.disableButtonBackgroundColor.color },
                        set: { workingTheme.disableButtonBackgroundColor = CodableColor($0) }
                    ))

                    Divider()

                    Text("Join Button")
                        .font(.subheadline.weight(.medium))

                    ColorPicker("Text Color", selection: Binding(
                        get: { workingTheme.joinButtonTextColor.color },
                        set: { workingTheme.joinButtonTextColor = CodableColor($0) }
                    ))

                    ColorPicker("Background", selection: Binding(
                        get: { workingTheme.joinButtonBackgroundColor.color },
                        set: { workingTheme.joinButtonBackgroundColor = CodableColor($0) }
                    ))
                }
                .padding()
            }
            .disabled(!isEditable)

            Divider()

            HStack(spacing: 12) {
                Button("Revert Changes") {
                    loadPreset(named: selectedPresetName)
                }

                Spacer()

                if isEditable {
                    Button(showingSavedConfirmation ? "Saved!" : "Save Preset") {
                        savePreset()
                        showingSavedConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showingSavedConfirmation = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Built-in preset (read-only)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .frame(width: 300)
    }

    // MARK: - Helpers

    private func loadPreset(named name: String) {
        workingTheme = presetManager.theme(named: name)
    }

    private func savePreset() {
        presetManager.savePreset(name: selectedPresetName, theme: workingTheme)
    }

    private func showImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .webP]

        if panel.runModal() == .OK, let url = panel.url {
            if let imageData = try? Data(contentsOf: url) {
                workingTheme.imageData = imageData
                workingTheme.backgroundType = .image
            }
        }
    }
}
