//
//  PreAlertPresetsSettingsView.swift
//  ZapCal
//

import SwiftUI
import EventKit
import UniformTypeIdentifiers

struct PreAlertPresetsSettingsView: View {
    @ObservedObject var presetManager = PreAlertPresetManager.shared
    @ObservedObject private var calendarService = CalendarService.shared
    @ObservedObject private var appleRemindersService = AppleRemindersService.shared
    @ObservedObject private var appSettings = AppSettings.shared

    @State private var selectedPresetName: String = "Coral Paper"
    @State private var workingTheme: PreAlertTheme
    @State private var showingSavedConfirmation = false
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
            PresetListSidebar(
                presets: presetManager.presets.map { .init(name: $0.name, isBuiltIn: presetManager.isBuiltIn($0.name)) },
                selectedPresetName: $selectedPresetName,
                defaultPresetName: "Coral Paper",
                assignKind: .preAlert,
                calendars: selectedCalendars,
                reminderLists: selectedReminderLists,
                uniqueName: { presetManager.uniqueName(base: $0) },
                validateName: { presetManager.preset(named: $0) == nil },
                onDuplicate: { from, newName in presetManager.duplicatePreset(from: from, newName: newName) },
                onRename: { from, to in
                    ThemeService.shared.updatePreAlertAssignments(from: from, to: to)
                    presetManager.renamePreset(from: from, to: to)
                },
                onDelete: { name in
                    ThemeService.shared.clearPreAlertAssignments(for: name)
                    presetManager.deletePreset(named: name)
                },
                onSelectionChange: { loadPreset(named: $0) }
            )

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
                Button("Show Preview") {
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
                            showPresetImagePicker { filename in
                                workingTheme.imageFileName = filename
                                workingTheme.backgroundType = .image
                            }
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

            PresetSaveRevertFooter(
                isEditable: isEditable,
                showingSavedConfirmation: $showingSavedConfirmation,
                onRevert: { loadPreset(named: selectedPresetName) },
                onSave: { presetManager.savePreset(name: selectedPresetName, theme: workingTheme) }
            )
        }
        .frame(width: 300)
    }

    // MARK: - Helpers

    private var selectedCalendars: [EKCalendar] {
        calendarService.availableCalendars
            .filter { appSettings.selectedCalendarIdentifiers.contains($0.calendarIdentifier) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var selectedReminderLists: [EKCalendar] {
        appleRemindersService.availableReminderLists
            .filter { appSettings.selectedReminderListIdentifiers.contains($0.calendarIdentifier) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func loadPreset(named name: String) {
        workingTheme = presetManager.theme(named: name)
    }
}
