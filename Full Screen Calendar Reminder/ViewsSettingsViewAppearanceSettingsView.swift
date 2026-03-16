//
//  PresetsSettingsView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PresetsSettingsView: View {
    @ObservedObject var presetManager = PresetManager.shared

    @State private var selectedPresetName: String = "Pinka Blua"
    @State private var selectedElement: AlertElementIdentifier? = .title
    @State private var workingTheme: AlertTheme
    @State private var showingSavedConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDuplicateDialog = false
    @State private var duplicateName = ""

    private static let availableFonts: [String] = {
        let families = NSFontManager.shared.availableFontFamilies.sorted()
        return ["System"] + families
    }()

    init() {
        _workingTheme = State(initialValue: PresetManager.shared.theme(named: "Pinka Blua"))
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
    }

    // MARK: - Preset List

    private var presetList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedPresetName) {
                ForEach(presetManager.presets) { preset in
                    HStack {
                        if presetManager.isBuiltIn(preset.name) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(preset.name)
                            .lineLimit(1)
                    }
                    .tag(preset.name)
                }
            }
            .onChange(of: selectedPresetName) { newValue in
                loadPreset(named: newValue)
            }

            Divider()

            VStack(spacing: 8) {
                Button("Duplicate") {
                    duplicateName = presetManager.uniqueName(base: selectedPresetName)
                    showingDuplicateDialog = true
                }
                .frame(maxWidth: .infinity)

                if !presetManager.isBuiltIn(selectedPresetName) {
                    Button("Delete", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }

                #if DEBUG
                Button("Reveal in Finder") {
                    presetManager.revealPresetsInFinder()
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                #endif
            }
            .padding(8)
        }
        .frame(width: 180)
        .alert("Duplicate Preset", isPresented: $showingDuplicateDialog) {
            TextField("Name", text: $duplicateName)
            Button("Cancel", role: .cancel) { }
            Button("Duplicate") {
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
                ThemeService.shared.clearAssignments(for: selectedPresetName)
                presetManager.deletePreset(named: selectedPresetName)
                selectedPresetName = "Pinka Blua"
            }
        } message: {
            Text("This will permanently delete \"\(selectedPresetName)\" and reset any calendars using it.")
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
                        }
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
                if let imageData = workingTheme.imageData,
                   let nsImage = NSImage(data: imageData) {
                    HStack {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 100)
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
                        ForEach(Self.availableFonts, id: \.self) { font in
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

                    Toggle("Italic", isOn: Binding(
                        get: { style.italic ?? false },
                        set: { newValue in
                            style.italic = newValue
                            workingTheme.elementStyles[element] = style
                        }
                    ))
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
            if let imageData = try? Data(contentsOf: url) {
                workingTheme.imageData = imageData
                workingTheme.backgroundType = .image
            }
        }
    }
}

#Preview {
    PresetsSettingsView()
        .frame(width: 800, height: 600)
}
