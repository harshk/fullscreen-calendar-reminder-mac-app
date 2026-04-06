//
//  TrialManager.swift
//  ZapCal
//
//  Created by Harsh Kalra on 4/6/26.
//

import Foundation
import StoreKit
import Combine

enum TrialState: Equatable {
    case loading
    case active(daysRemaining: Int)
    case expired
    case purchased
}

@MainActor
class TrialManager: ObservableObject {
    static let shared = TrialManager()

    static let trialDurationDays = 7

    @Published var trialState: TrialState = .loading

    private init() {
        refreshState()
    }

    func refreshState() {
        Task {
            await evaluateTrialState()
        }
    }

    private func evaluateTrialState() async {
        // Check purchase first
        if StoreManager.shared.isPurchased {
            trialState = .purchased
            return
        }

        // Get original purchase date from App Store receipt
        if let installDate = await getOriginalPurchaseDate() {
            let calendar = Calendar.current
            let expiryDate = calendar.date(byAdding: .day, value: Self.trialDurationDays, to: installDate)!
            let now = Date()

            if now < expiryDate {
                let remaining = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiryDate)).day ?? 0
                trialState = .active(daysRemaining: max(1, remaining))
            } else {
                trialState = .expired
            }
        } else {
            // Receipt unavailable (e.g. debug build) — fall back to UserDefaults
            let installDate = getOrSetLocalInstallDate()
            let calendar = Calendar.current
            let expiryDate = calendar.date(byAdding: .day, value: Self.trialDurationDays, to: installDate)!
            let now = Date()

            if now < expiryDate {
                let remaining = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiryDate)).day ?? 0
                trialState = .active(daysRemaining: max(1, remaining))
            } else {
                trialState = .expired
            }
        }
    }

    // MARK: - App Store Receipt

    private func getOriginalPurchaseDate() async -> Date? {
        do {
            let appTransaction = try await AppTransaction.shared
            switch appTransaction {
            case .verified(let transaction):
                return transaction.originalPurchaseDate
            case .unverified:
                return nil
            }
        } catch {
            // Expected in debug/Xcode builds where no receipt exists
            print("AppTransaction unavailable: \(error)")
            return nil
        }
    }

    // MARK: - Local Fallback (Debug Builds)

    private static let localInstallDateKey = "zapcal_local_install_date"

    private func getOrSetLocalInstallDate() -> Date {
        if let stored = UserDefaults.standard.object(forKey: Self.localInstallDateKey) as? Date {
            return stored
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: Self.localInstallDateKey)
        return now
    }
}
