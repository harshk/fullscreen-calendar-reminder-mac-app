//
//  ViewsAboutView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 4/7/26.
//

import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("ZapCal")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, -10)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("by Spotless Mind Software")
                .font(.system(size: 14, weight: .medium))

            VStack(spacing: 4) {
                Text("Feedback & Questions:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Link("spotlessmindsoftware@gmail.com",
                     destination: URL(string: "mailto:spotlessmindsoftware@gmail.com")!)
                    .font(.system(size: 12))
            }
        }
        .padding(.vertical, 24)
        .frame(width: 320)
    }
}
 
#Preview {
    AboutView()
}
