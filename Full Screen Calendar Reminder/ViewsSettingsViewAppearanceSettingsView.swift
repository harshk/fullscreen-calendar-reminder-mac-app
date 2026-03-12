//
//  AppearanceSettingsView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import AppKit
import EventKit
import UniformTypeIdentifiers

struct AppearanceSettingsView: View {
    @ObservedObject var themeService = ThemeService.shared
    @ObservedObject var calendarService = CalendarService.shared
    
    @State private var selectedCalendarID = "default"
    @State private var selectedElement: AlertElementIdentifier? = .title
    @State private var workingTheme: AlertTheme
    @State private var showingResetConfirmation = false
    @State private var showingImagePicker = false
    @State private var showingSavedConfirmation = false
    @State private var fontSearchText = ""

    private static let availableFonts: [String] = {
        let families = NSFontManager.shared.availableFontFamilies.sorted()
        return ["System"] + families
    }()

    init() {
        _workingTheme = State(initialValue: ThemeService.shared.getTheme(for: "default"))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Preview pane
            previewPane
            
            Divider()
            
            // Editor pane
            editorPane
        }
    }
    
    // MARK: - Preview Pane
    
    private var previewPane: some View {
        VStack(spacing: 0) {
            // Calendar selector
            HStack {
                Picker("Editing Theme For:", selection: $selectedCalendarID) {
                    Text("Default Theme").tag("default")
                    
                    if !calendarService.availableCalendars.isEmpty {
                        Divider()
                        
                        ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { calendar in
                            Text(calendar.title).tag(calendar.calendarIdentifier)
                        }
                    }
                }
                .onChange(of: selectedCalendarID) { newValue in
                    loadTheme(for: newValue)
                }
            }
            .padding()
            
            Divider()
            
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
                        onJoinMeeting: { _ in }
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
                
                Menu("More") {
                    Menu("Duplicate From...") {
                        if selectedCalendarID != "default" {
                            Button("Default Theme") {
                                duplicateTheme(from: "default")
                            }
                        }

                        ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { calendar in
                            if calendar.calendarIdentifier != selectedCalendarID {
                                Button(calendar.title) {
                                    duplicateTheme(from: calendar.calendarIdentifier)
                                }
                            }
                        }
                    }

                    Button("Reset to Default Theme") {
                        showingResetConfirmation = true
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .alert("Reset Theme?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetTheme()
            }
        } message: {
            Text("This will reset all customizations for this theme to the default theme.")
        }
    }
    
    // MARK: - Editor Pane
    
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
                        // Element properties
                        elementProperties(for: element)
                    }
                }
                .padding()
            }

            Divider()

            // Save/Cancel buttons pinned to bottom
            HStack(spacing: 12) {
                Button("Revert Changes") {
                    loadTheme(for: selectedCalendarID)
                }

                Spacer()

                Button(showingSavedConfirmation ? "Saved!" : "Save Theme") {
                    saveTheme()
                    showingSavedConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingSavedConfirmation = false
                    }
                }
                .buttonStyle(.borderedProminent)
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
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                Button(action: { selectedElement = nil }) {
                    VStack {
                        Image(systemName: "photo")
                        Text("Background")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedElement == nil ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedElement == nil ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(AlertElementIdentifier.allCases, id: \.self) { element in
                    Button(action: { selectedElement = element }) {
                        VStack {
                            Image(systemName: iconForElement(element))
                            Text(labelForElement(element))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedElement == element ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
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
                
                // Font Size
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
                
                // Font Weight
                Picker("Font Weight", selection: Binding(
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
                
                // Font Color
                ColorPicker("Color", selection: Binding(
                    get: { style.fontColor.color },
                    set: { newValue in
                        style.fontColor = CodableColor(newValue)
                        workingTheme.elementStyles[element] = style
                    }
                ))
                
                // Text Alignment
                Picker("Alignment", selection: Binding(
                    get: { style.textAlignment },
                    set: { newValue in
                        style.textAlignment = newValue
                        workingTheme.elementStyles[element] = style
                    }
                )) {
                    Text("Left").tag(TextAlignment.leading)
                    Text("Center").tag(TextAlignment.center)
                    Text("Right").tag(TextAlignment.trailing)
                }
                .pickerStyle(.segmented)

                // Uppercase toggle (for text elements only)
                if element != .dismissButton {
                    Toggle("Uppercase", isOn: Binding(
                        get: { style.uppercased ?? false },
                        set: { newValue in
                            style.uppercased = newValue
                            workingTheme.elementStyles[element] = style
                        }
                    ))
                }

                // Button-specific properties
                if element == .joinButton {
                    Divider()
                    
                    Text("Button Properties")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ColorPicker("Background Color", selection: Binding(
                        get: { style.buttonBackgroundColor?.color ?? .blue },
                        set: { newValue in
                            style.buttonBackgroundColor = CodableColor(newValue)
                            workingTheme.elementStyles[element] = style
                        }
                    ))
                    
                    ColorPicker("Text Color", selection: Binding(
                        get: { style.buttonTextColor?.color ?? .white },
                        set: { newValue in
                            style.buttonTextColor = CodableColor(newValue)
                            workingTheme.elementStyles[element] = style
                        }
                    ))
                    
                    Stepper(
                        "Corner Radius: \(Int(style.buttonCornerRadius ?? 12))pt",
                        value: Binding(
                            get: { style.buttonCornerRadius ?? 12 },
                            set: { newValue in
                                style.buttonCornerRadius = newValue
                                workingTheme.elementStyles[element] = style
                            }
                        ),
                        in: 0...50,
                        step: 2
                    )
                    
                    Stepper(
                        "Horizontal Padding: \(Int(style.buttonPaddingHorizontal ?? 24))pt",
                        value: Binding(
                            get: { style.buttonPaddingHorizontal ?? 24 },
                            set: { newValue in
                                style.buttonPaddingHorizontal = newValue
                                workingTheme.elementStyles[element] = style
                            }
                        ),
                        in: 0...100,
                        step: 4
                    )
                    
                    Stepper(
                        "Vertical Padding: \(Int(style.buttonPaddingVertical ?? 12))pt",
                        value: Binding(
                            get: { style.buttonPaddingVertical ?? 12 },
                            set: { newValue in
                                style.buttonPaddingVertical = newValue
                                workingTheme.elementStyles[element] = style
                            }
                        ),
                        in: 0...50,
                        step: 2
                    )
                }
                
                // Dismiss button-specific properties
                if element == .dismissButton {
                    Divider()
                    
                    Text("Icon Properties")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
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
        case .queueCounter: return "Counter"
        case .dismissButton: return "Dismiss"
        }
    }
    
    private func loadTheme(for calendarID: String) {
        workingTheme = themeService.getTheme(for: calendarID)
        selectedElement = .title
    }
    
    private func saveTheme() {
        themeService.setTheme(workingTheme, for: selectedCalendarID)
    }
    
    private func resetTheme() {
        themeService.resetTheme(for: selectedCalendarID)
        loadTheme(for: selectedCalendarID)
    }

    private func duplicateTheme(from sourceID: String) {
        workingTheme = themeService.getTheme(for: sourceID)
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
    AppearanceSettingsView()
        .frame(width: 800, height: 600)
}
