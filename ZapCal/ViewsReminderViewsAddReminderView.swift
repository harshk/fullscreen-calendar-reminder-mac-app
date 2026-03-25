//
//  AddReminderView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI

struct AddReminderView: View {
    @ObservedObject var reminderService = ReminderService.shared
    
    @State private var title = ""
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add ZapCal Reminder")
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
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveReminder()
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
    
    private func saveReminder() {
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
            try reminderService.addReminder(title: title, scheduledDate: combinedDateTime)
            NSApp.keyWindow?.close()
        } catch {
            errorMessage = "Failed to save reminder: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    AddReminderView()
}
