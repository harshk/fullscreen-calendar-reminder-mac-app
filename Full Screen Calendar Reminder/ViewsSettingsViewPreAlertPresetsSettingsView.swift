//
//  PreAlertPresetsSettingsView.swift
//  Full Screen Calendar Reminder
//

import SwiftUI
import EventKit
import UniformTypeIdentifiers

struct PreAlertPresetsSettingsView: View {
    @ObservedObject var presetManager = PreAlertPresetManager.shared
    @ObservedObject private var calendarService = CalendarService.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var themeService = ThemeService.shared

    @State private var selectedPresetName: String = "Coral Paper"
    @State private var workingTheme: PreAlertTheme
    @State private var showingSavedConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDuplicateDialog = false
    @State private var duplicateName = ""
    @State private var showingRenameDialog = false
    @State private var renameTarget = ""
    @State private var assignCalendarPresetName: String? = nil
    @State private var cachedBackgroundImage: NSImage? = nil
    @State private var cachedThumbnail: NSImage? = nil

    init() {
        _workingTheme = State(initialValue: PreAlertPresetManager.shared.theme(named: "Coral Paper"))
    }

    private func recomputeBackgroundImage() {
        cachedBackgroundImage = nil
        guard let filename = workingTheme.imageFileName else { return }
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2
        let blurRadius = (workingTheme.imageBlurRadius ?? 0.3) * 30
        ImageStore.loadBlurredAsync(filename, targetSize: CGSize(width: 460 * scaleFactor, height: 108 * scaleFactor), blurRadius: blurRadius) { image in
            cachedBackgroundImage = image
        }
    }

    private func recomputeThumbnail() {
        cachedThumbnail = nil
        guard let filename = workingTheme.imageFileName else { return }
        let maxDim = 160 * (NSScreen.main?.backingScaleFactor ?? 2)
        ImageStore.loadThumbnailAsync(filename, maxDimension: maxDim) { image in
            cachedThumbnail = image
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            presetList

            Divider()

            previewPane

            Divider()

            editorPane
        }
        .onAppear { recomputeBackgroundImage(); recomputeThumbnail() }
        .onChange(of: workingTheme.imageFileName) { _ in recomputeBackgroundImage(); recomputeThumbnail() }
        .onChange(of: workingTheme.imageBlurRadius) { _ in recomputeBackgroundImage() }
        .onChange(of: workingTheme.backgroundType) { _ in recomputeBackgroundImage() }
        .onReceive(SettingsWindowVisible.shared.$isVisible) { visible in
            if visible {
                recomputeBackgroundImage(); recomputeThumbnail()
            } else {
                cachedBackgroundImage = nil; cachedThumbnail = nil
            }
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
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .tag(preset.name)
                        .contextMenu {
                            Button("Copy") {
                                duplicateName = presetManager.uniqueName(base: preset.name)
                                selectedPresetName = preset.name
                                showingDuplicateDialog = true
                            }
                            if !selectedCalendars.isEmpty {
                                Button("Assign to Calendar...") {
                                    assignCalendarPresetName = preset.name
                                }
                            }
                        }
                    }
                }
                Section("Custom Presets") {
                    ForEach(presetManager.presets.filter { !presetManager.isBuiltIn($0.name) }) { preset in
                        HStack {
                            Text(preset.name)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .tag(preset.name)
                            .contextMenu {
                                Button("Copy") {
                                    duplicateName = presetManager.uniqueName(base: preset.name)
                                    selectedPresetName = preset.name
                                    showingDuplicateDialog = true
                                }
                                Button("Rename") {
                                    renameTarget = preset.name
                                    showingRenameDialog = true
                                }
                                if !selectedCalendars.isEmpty {
                                    Button("Assign to Calendar...") {
                                        assignCalendarPresetName = preset.name
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
        .sheet(isPresented: $showingDuplicateDialog) {
            PresetNameSheet(
                title: "Copy Preset",
                message: "Enter a name for the new preset.",
                actionLabel: "Copy",
                initialName: duplicateName,
                validate: { presetManager.preset(named: $0) == nil },
                onSubmit: { name in
                    presetManager.duplicatePreset(from: selectedPresetName, newName: name)
                    selectedPresetName = name
                }
            )
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
        .sheet(isPresented: $showingRenameDialog) {
            PresetNameSheet(
                title: "Rename Preset",
                message: "Enter a new name for \"\(renameTarget)\".",
                actionLabel: "Rename",
                initialName: renameTarget,
                validate: { $0 == renameTarget || presetManager.preset(named: $0) == nil },
                onSubmit: { name in
                    ThemeService.shared.updatePreAlertAssignments(from: renameTarget, to: name)
                    presetManager.renamePreset(from: renameTarget, to: name)
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
                    calendars: selectedCalendars,
                    themeService: themeService,
                    kind: .preAlert
                )
            }
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
                backgroundImage: cachedBackgroundImage,
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
                        if workingTheme.imageFileName != nil,
                           let nsImage = cachedThumbnail {
                            HStack {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 80)
                                    .cornerRadius(8)

                                Spacer()

                                Button("Remove") {
                                    workingTheme.imageFileName = nil
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

    private var selectedCalendars: [EKCalendar] {
        calendarService.availableCalendars
            .filter { appSettings.selectedCalendarIdentifiers.contains($0.calendarIdentifier) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

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
            if let data = try? Data(contentsOf: url) {
                workingTheme.imageFileName = ImageStore.save(data)
                workingTheme.backgroundType = .image
            }
        }
    }
}
