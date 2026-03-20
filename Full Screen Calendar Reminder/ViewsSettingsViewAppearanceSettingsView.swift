//
//  PresetsSettingsView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import AppKit
import Combine
import EventKit
import UniformTypeIdentifiers

class FontCache: ObservableObject {
    static let shared = FontCache()
    @Published private(set) var fonts: [String] = ["System"]

    private init() {
        DispatchQueue.global(qos: .userInitiated).async {
            let families = NSFontManager.shared.availableFontFamilies.sorted()
            let result = ["System"] + families
            DispatchQueue.main.async {
                self.fonts = result
            }
        }
    }
}

struct PresetsSettingsView: View {
    @ObservedObject var presetManager = PresetManager.shared
    @ObservedObject private var fontCache = FontCache.shared
    @ObservedObject private var calendarService = CalendarService.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var themeService = ThemeService.shared

    @State private var selectedPresetName: String = "Coral Paper FS"
    @State private var selectedElement: AlertElementIdentifier? = .title
    @State private var workingTheme: AlertTheme
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
        _workingTheme = State(initialValue: PresetManager.shared.theme(named: "Coral Paper FS"))
    }

    private func recomputeBackgroundImage() {
        cachedBackgroundImage = nil
        guard let filename = workingTheme.imageFileName else { return }
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2
        let blurRadius = (workingTheme.imageBlurRadius ?? 0.3) * 50
        ImageStore.loadBlurredAsync(filename, targetSize: CGSize(width: 800 * scaleFactor, height: 500 * scaleFactor), blurRadius: blurRadius) { image in
            cachedBackgroundImage = image
        }
    }

    private func recomputeThumbnail() {
        cachedThumbnail = nil
        guard let filename = workingTheme.imageFileName else { return }
        let maxDim = 200 * (NSScreen.main?.backingScaleFactor ?? 2)
        ImageStore.loadThumbnailAsync(filename, maxDimension: maxDim) { image in
            cachedThumbnail = image
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Preset list
            presetList

            Divider()

            // Preview pane
            previewPane

            Divider()

            // Editor pane
            editorPane
        }
        .onAppear { recomputeBackgroundImage(); recomputeThumbnail() }
        .onChange(of: workingTheme.imageFileName) { _ in recomputeBackgroundImage(); recomputeThumbnail() }
        .onChange(of: workingTheme.imageBlurRadius) { _ in recomputeBackgroundImage() }
        .onChange(of: workingTheme.backgroundType) { _ in recomputeBackgroundImage(); recomputeThumbnail() }
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
                        Text(preset.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
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
                ThemeService.shared.clearAssignments(for: selectedPresetName)
                presetManager.deletePreset(named: selectedPresetName)
                selectedPresetName = "Coral Paper FS"
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
                    ThemeService.shared.updateAssignments(from: renameTarget, to: name)
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
                    kind: .fullScreen
                )
            }
        }
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        VStack(spacing: 0) {
            // Preview - render at actual screen size and scale down to fit
            GeometryReader { geometry in
                let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
                let scaleX = geometry.size.width / screenSize.width
                let scaleY = geometry.size.height / screenSize.height
                let scale = min(scaleX, scaleY)

                ZStack {
                    Color.black.opacity(0.9)

                    FullScreenAlertView(
                        alertItem: .calendarEvent(CalendarEvent.mock()),
                        theme: workingTheme,
                        queuePosition: 1,
                        queueTotal: 3,
                        isPrimaryScreen: true,
                        onDismiss: {},
                        onSnooze: { _ in },
                        onJoinMeeting: { _ in },
                        onElementTap: { element in
                            selectedElement = element
                        },
                        backgroundImage: cachedBackgroundImage
                    )
                    .frame(width: screenSize.width, height: screenSize.height)
                    .scaleEffect(scale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button("Preview Full Screen") {
                    AlertCoordinator.shared.showPreviewAlert(theme: workingTheme)
                }

                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Editor Pane

    private var isEditable: Bool {
        presetManager.isEditable(selectedPresetName)
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Element selector
                    elementSelector

                    Divider()

                    // Background properties (when no element selected)
                    if selectedElement == nil {
                        backgroundProperties
                    } else if let element = selectedElement {
                        elementProperties(for: element)
                    }
                }
                .padding()
            }
            .disabled(!isEditable)

            Divider()

            // Save/Revert buttons pinned to bottom
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
        .frame(width: 350)
    }

    // MARK: - Element Selector

    private var elementSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Element")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                Button(action: { selectedElement = nil }) {
                    VStack(spacing: 2) {
                        Image(systemName: "photo")
                            .font(.caption2)
                        Text("Background")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(selectedElement == nil ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selectedElement == nil ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(AlertElementIdentifier.allCases, id: \.self) { element in
                    Button(action: { selectedElement = element }) {
                        VStack(spacing: 2) {
                            Image(systemName: iconForElement(element))
                                .font(.caption2)
                            Text(labelForElement(element))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(selectedElement == element ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedElement == element ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Background Properties

    private var backgroundProperties: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Background Properties")
                .font(.headline)

            Picker("Type", selection: $workingTheme.backgroundType) {
                Text("Solid Color").tag(AlertTheme.BackgroundType.solidColor)
                Text("Image").tag(AlertTheme.BackgroundType.image)
            }
            .pickerStyle(.segmented)

            if workingTheme.backgroundType == .solidColor {
                ColorPicker("Color", selection: Binding(
                    get: { workingTheme.solidColor.color },
                    set: { workingTheme.solidColor = CodableColor($0) }
                ))

                Slider(
                    value: $workingTheme.solidColorOpacity,
                    in: 0.5...1.0,
                    step: 0.05
                ) {
                    Text("Opacity: \(Int(workingTheme.solidColorOpacity * 100))%")
                }
            } else {
                if workingTheme.imageFileName != nil,
                   let nsImage = cachedThumbnail {
                    HStack {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 100)
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
        }
    }

    // MARK: - Element Properties

    @ViewBuilder
    private func elementProperties(for element: AlertElementIdentifier) -> some View {
        if var style = workingTheme.elementStyles[element] {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(labelForElement(element)) Properties")
                    .font(.headline)

                if element != .dismissButton {
                    // Font Family
                    Picker("Font Family", selection: Binding(
                        get: { style.fontFamily },
                        set: { newValue in
                            style.fontFamily = newValue
                            workingTheme.elementStyles[element] = style
                        }
                    )) {
                        ForEach(fontCache.fonts, id: \.self) { font in
                            Text(font)
                                .font(.custom(font, size: 13))
                                .tag(font)
                        }
                    }

                    // "Change all fonts" button
                    if workingTheme.elementStyles.contains(where: { $0.key != element && $0.value.fontFamily != style.fontFamily }) {
                        Button("Change all fonts to: \(style.fontFamily)") {
                            for key in workingTheme.elementStyles.keys {
                                workingTheme.elementStyles[key]?.fontFamily = style.fontFamily
                            }
                        }
                        .font(.caption)
                    }

                    // Font Size + Weight
                    HStack {
                        Stepper(
                            "Font Size: \(Int(style.fontSize))pt",
                            value: Binding(
                                get: { style.fontSize },
                                set: { newValue in
                                    style.fontSize = newValue
                                    workingTheme.elementStyles[element] = style
                                }
                            ),
                            in: 8...200,
                            step: 2
                        )

                        Picker("Weight", selection: Binding(
                            get: { style.fontWeight },
                            set: { newValue in
                                style.fontWeight = newValue
                                workingTheme.elementStyles[element] = style
                            }
                        )) {
                            Text("Light").tag(Font.Weight.light)
                            Text("Regular").tag(Font.Weight.regular)
                            Text("Medium").tag(Font.Weight.medium)
                            Text("Semibold").tag(Font.Weight.semibold)
                            Text("Bold").tag(Font.Weight.bold)
                        }
                    }

                    // Letter Spacing
                    Stepper(
                        "Letter Spacing: \(String(format: "%.1f", style.letterSpacing ?? 0))pt",
                        value: Binding(
                            get: { style.letterSpacing ?? 0 },
                            set: { newValue in
                                style.letterSpacing = newValue
                                workingTheme.elementStyles[element] = style
                            }
                        ),
                        in: -15...30,
                        step: 0.5
                    )

                    // Vertical scale
                    Stepper(
                        "Vertical Stretch: \(String(format: "%.0f%%", (style.verticalScale ?? 1.0) * 100))",
                        value: Binding(
                            get: { style.verticalScale ?? 1.0 },
                            set: { newValue in
                                style.verticalScale = newValue
                                workingTheme.elementStyles[element] = style
                            }
                        ),
                        in: 0.5...2.0,
                        step: 0.1
                    )

                    // Font Color (+ Background Color for buttons)
                    HStack {
                        ColorPicker("Text Color", selection: Binding(
                            get: { style.fontColor.color },
                            set: { newValue in
                                style.fontColor = CodableColor(newValue)
                                workingTheme.elementStyles[element] = style
                            }
                        ))
                        if element == .joinButton || element == .snoozeButton {
                            ColorPicker("Background", selection: Binding(
                                get: { style.buttonBackgroundColor?.color ?? .blue },
                                set: { newValue in
                                    style.buttonBackgroundColor = CodableColor(newValue)
                                    workingTheme.elementStyles[element] = style
                                }
                            ))
                        }
                    }

                    // Uppercase & Italic toggles
                    Toggle("Uppercase", isOn: Binding(
                        get: { style.uppercased ?? false },
                        set: { newValue in
                            style.uppercased = newValue
                            workingTheme.elementStyles[element] = style
                        }
                    ))

                    let hasItalic = style.fontFamily == "System" || {
                        guard let members = NSFontManager.shared.availableMembers(ofFontFamily: style.fontFamily) else { return false }
                        return members.contains { member in
                            let traits = (member[3] as? Int) ?? 0
                            return traits & Int(NSFontTraitMask.italicFontMask.rawValue) != 0
                        }
                    }()

                    Toggle("Italic", isOn: Binding(
                        get: { style.italic ?? false },
                        set: { newValue in
                            style.italic = newValue
                            workingTheme.elementStyles[element] = style
                        }
                    ))
                    .disabled(!hasItalic)
                }

                // Dismiss button icon properties
                if element == .dismissButton {
                    Stepper(
                        "Icon Size: \(Int(style.iconSize ?? 32))pt",
                        value: Binding(
                            get: { style.iconSize ?? 32 },
                            set: { newValue in
                                style.iconSize = newValue
                                workingTheme.elementStyles[element] = style
                            }
                        ),
                        in: 16...64,
                        step: 4
                    )

                    ColorPicker("Icon Color", selection: Binding(
                        get: { style.iconColor?.color ?? .white },
                        set: { newValue in
                            style.iconColor = CodableColor(newValue)
                            workingTheme.elementStyles[element] = style
                        }
                    ))

                    ColorPicker("Background Color", selection: Binding(
                        get: { style.buttonBackgroundColor?.color ?? Color.white.opacity(0.2) },
                        set: { newValue in
                            style.buttonBackgroundColor = CodableColor(newValue)
                            workingTheme.elementStyles[element] = style
                        }
                    ))
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func iconForElement(_ element: AlertElementIdentifier) -> String {
        switch element {
        case .title: return "textformat.size.larger"
        case .startTime: return "clock"
        case .location: return "location"
        case .calendarName: return "calendar"
        case .joinButton: return "video.fill"
        case .snoozeButton: return "bell.badge"
        case .queueCounter: return "number"
        case .dismissButton: return "xmark"
        }
    }

    private func labelForElement(_ element: AlertElementIdentifier) -> String {
        switch element {
        case .title: return "Title"
        case .startTime: return "Time"
        case .location: return "Location"
        case .calendarName: return "Calendar"
        case .joinButton: return "Join Button"
        case .snoozeButton: return "Snooze"
        case .queueCounter: return "Counter"
        case .dismissButton: return "Dismiss"
        }
    }

    private var selectedCalendars: [EKCalendar] {
        calendarService.availableCalendars
            .filter { appSettings.selectedCalendarIdentifiers.contains($0.calendarIdentifier) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func loadPreset(named name: String) {
        workingTheme = presetManager.theme(named: name)
        selectedElement = .title
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

// MARK: - Preset Name Sheet

struct PresetNameSheet: View {
    let title: String
    let message: String
    let actionLabel: String
    let initialName: String
    let validate: (String) -> Bool
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var error = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { submit() }

            if !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(actionLabel) { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear { name = initialName }
    }

    private func submit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !validate(trimmed) {
            error = "A preset named \"\(trimmed)\" already exists."
            return
        }
        onSubmit(trimmed)
        dismiss()
    }
}

// MARK: - Assign Calendars Sheet

struct AssignCalendarsSheet: View {
    enum Kind { case fullScreen, preAlert }

    let presetName: String
    let calendars: [EKCalendar]
    @ObservedObject var themeService: ThemeService
    let kind: Kind

    @Environment(\.dismiss) private var dismiss

    private var allAssigned: Bool {
        calendars.allSatisfy { isAssigned($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Assign \"\(presetName)\"")
                .font(.headline)
                .padding()

            Divider()

            List {
                toggleRow(label: "All Calendars", isOn: Binding(
                    get: { allAssigned },
                    set: { newValue in
                        for calendar in calendars {
                            if newValue {
                                assign(presetName, to: calendar)
                            } else {
                                resetAssignment(for: calendar)
                            }
                        }
                    }
                ))
                .fontWeight(.medium)

                ForEach(calendars, id: \.calendarIdentifier) { calendar in
                    toggleRow(
                        label: calendar.title,
                        color: calendar.cgColor.map { Color(cgColor: $0) },
                        isOn: Binding(
                            get: { isAssigned(calendar) },
                            set: { newValue in
                                if newValue {
                                    assign(presetName, to: calendar)
                                } else {
                                    resetAssignment(for: calendar)
                                }
                            }
                        )
                    )
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 300, height: min(CGFloat(calendars.count * 28 + 150), 400))
    }

    private func toggleRow(label: String, color: Color? = nil, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.checkbox)
            if let color {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 14, height: 14)
            }
            Text(label)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
    }

    private func isAssigned(_ calendar: EKCalendar) -> Bool {
        switch kind {
        case .fullScreen:
            return themeService.assignedPresetName(for: calendar.calendarIdentifier) == presetName
        case .preAlert:
            return themeService.assignedPreAlertPresetName(for: calendar.calendarIdentifier) == presetName
        }
    }

    private func assign(_ preset: String, to calendar: EKCalendar) {
        switch kind {
        case .fullScreen:
            themeService.setPreset(preset, for: calendar.calendarIdentifier)
        case .preAlert:
            themeService.setPreAlertPreset(preset, for: calendar.calendarIdentifier)
        }
    }

    private func resetAssignment(for calendar: EKCalendar) {
        switch kind {
        case .fullScreen:
            themeService.resetAssignment(for: calendar.calendarIdentifier)
        case .preAlert:
            themeService.resetPreAlertAssignment(for: calendar.calendarIdentifier)
        }
    }
}

#Preview {
    PresetsSettingsView()
        .frame(width: 800, height: 600)
}
