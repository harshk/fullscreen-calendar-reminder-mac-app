//
//  ManageRemindersView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI

struct ManageRemindersView: View {
    @ObservedObject var reminderService = ReminderService.shared

    @State private var selectedReminder: CustomReminder?
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Reminders")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    NSApp.keyWindow?.close()
                }
            }
            .padding()
            
            Divider()
            
            // Content
            if reminderService.upcomingReminders.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if !reminderService.upcomingReminders.isEmpty {
                            upcomingSection
                        }
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showingEditSheet) {
            if let reminder = selectedReminder {
                EditReminderView(reminder: reminder)
            }
        }
        .alert("Delete Reminder?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let reminder = selectedReminder {
                    deleteReminder(reminder)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Reminders")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Create custom reminders from the menu bar.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Upcoming Section
    
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(reminderService.upcomingReminders) { reminder in
                ReminderRow(
                    reminder: reminder,
                    onEdit: {
                        selectedReminder = reminder
                        showingEditSheet = true
                    },
                    onDelete: {
                        selectedReminder = reminder
                        showingDeleteConfirmation = true
                    }
                )
            }
        }
    }
    
    private func deleteReminder(_ reminder: CustomReminder) {
        do {
            try reminderService.deleteReminder(reminder)
        } catch {
            print("Failed to delete reminder: \(error)")
        }
    }
}

// MARK: - Reminder Row

struct ReminderRow: View {
    let reminder: CustomReminder
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("Edit")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(formatDateTime(reminder.scheduledDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05))
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Edit Reminder View

struct EditReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var reminderService = ReminderService.shared
    
    let reminder: CustomReminder
    
    @State private var title: String
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(reminder: CustomReminder) {
        self.reminder = reminder
        _title = State(initialValue: reminder.title)
        _selectedDate = State(initialValue: reminder.scheduledDate)
        _selectedTime = State(initialValue: reminder.scheduledDate)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Reminder")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                }
            }
            .formStyle(.grouped)
            
            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private var combinedDateTime: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined) ?? Date()
    }
    
    private var isValid: Bool {
        !title.isEmpty && 
        title.count <= 200 && 
        combinedDateTime > Date()
    }
    
    private func saveChanges() {
        guard isValid else {
            if title.isEmpty {
                errorMessage = "Title is required"
            } else if title.count > 200 {
                errorMessage = "Title must be 200 characters or less"
            } else if combinedDateTime <= Date() {
                errorMessage = "Reminder must be scheduled in the future"
            }
            showError = true
            return
        }
        
        do {
            try reminderService.updateReminder(reminder, title: title, scheduledDate: combinedDateTime)
            dismiss()
        } catch {
            errorMessage = "Failed to update reminder: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    ManageRemindersView()
}
