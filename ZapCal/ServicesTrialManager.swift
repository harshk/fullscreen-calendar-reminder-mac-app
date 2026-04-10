//
//  TrialManager.swift
//  ZapCal
//
//  Created by Harsh Kalra on 4/6/26.
//

import Foundation
import StoreKit
import Combine
import os

private let logger = Logger(subsystem: "spotlessmindsoftware.ZapCal", category: "TrialManager")

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

    /// Checks AppTransaction environment to detect TestFlight (sandbox)
    /// vs App Store (production). DEBUG builds are excluded so the full
    /// purchase flow can be tested locally in Xcode.
    private func checkIsTestFlight() async -> Bool {
        #if DEBUG
        return false
        #else
        guard let result = try? await AppTransaction.shared else { return false }
        switch result {
        case .verified(let transaction):
            let env = transaction.environment
            logger.notice("AppTransaction environment: \(env.rawValue, privacy: .public)")
            return env == .sandbox
        case .unverified:
            return false
        }
        #endif
    }

    private func evaluateTrialState() async {
        // TestFlight users bypass trial/purchase entirely.
        let isTestFlight = await checkIsTestFlight()
        if isTestFlight {
            logger.notice("TestFlight build detected — bypassing trial")
            trialState = .purchased
            return
        }

        // Ensure purchase status is up-to-date before checking.
        // StoreManager's init fires an async task that may not have
        // finished yet, so we explicitly await the check here.
        await StoreManager.shared.checkPurchaseStatus()
        if StoreManager.shared.isPurchased {
            trialState = .purchased
            return
        }

        // Determine install date.
        // In DEBUG builds use a local UserDefaults date so testers can reset it.
        // In production (App Store) use the tamper-proof receipt date.
        let installDate: Date
        #if DEBUG
        installDate = getOrSetLocalInstallDate()
        print("[TrialManager] DEBUG — using local install date: \(installDate)")
        #else
        if let receiptDate = await getOriginalPurchaseDate() {
            installDate = receiptDate
        } else {
            installDate = getOrSetLocalInstallDate()
        }
        #endif

        let calendar = Calendar.current
        let expiryDate = calendar.date(byAdding: .day, value: Self.trialDurationDays, to: installDate)!
        let now = Date()

        if now < expiryDate {
            let remaining = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiryDate)).day ?? 0
            trialState = .active(daysRemaining: max(1, remaining))
        } else {
            trialState = .expired
        }
        print("[TrialManager] install: \(installDate), expiry: \(expiryDate), state: \(trialState)")
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
