import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("showSystemServices") private var showSystemServices = true
    @AppStorage("hideDisabledServices") private var hideDisabledServices = false
    @AppStorage("terminalFontSize") private var terminalFontSize = 12.0
    @AppStorage("terminalTheme") private var terminalTheme = "classicGreen"
    
    @State private var helperStatus: SMAppService.Status = .notFound
    @State private var statusMessage: String?
    @State private var isProcessing = false
    
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        TabView {
            // General Settings Tab
            VStack(alignment: .leading, spacing: 0) {
                Grid(alignment: .top, horizontalSpacing: 12, verticalSpacing: 16) {
                    GridRow {
                        Text(String(localized: "Services:"))
                            .gridCellAnchor(.topTrailing)
                            .fontWeight(.medium)
                            .padding(.top, 3)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(String(localized: "Show System Services"), isOn: $showSystemServices)
                                    .toggleStyle(.checkbox)
                                Text(String(localized: "Display read-only system agents and daemons protected by SIP."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(String(localized: "Hide Disabled Services"), isOn: $hideDisabledServices)
                                    .toggleStyle(.checkbox)
                                Text(String(localized: "Hide services that have been explicitly disabled in launchd."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .gridCellAnchor(.topLeading)
                    }
                }
                Spacer()
            }
            .padding(24)
            .tabItem {
                Label(String(localized: "General"), systemImage: "gearshape")
            }
            
            // Helper Tool Settings Tab
            VStack(alignment: .leading, spacing: 0) {
                Grid(alignment: .top, horizontalSpacing: 12, verticalSpacing: 16) {
                    GridRow {
                        Text(String(localized: "Helper Status:"))
                            .gridCellAnchor(.topTrailing)
                            .fontWeight(.medium)
                            .padding(.top, 2)
                        
                        HStack(spacing: 8) {
                            Text(statusText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(statusColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(statusColor.opacity(0.12))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(statusColor.opacity(0.25), lineWidth: 1)
                                )
                            
                            if isProcessing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .gridCellAnchor(.topLeading)
                    }
                    
                    GridRow {
                        Text(String(localized: "Operations:"))
                            .gridCellAnchor(.topTrailing)
                            .fontWeight(.medium)
                            .padding(.top, 3)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                if helperStatus == .enabled {
                                    Button(role: .destructive) {
                                        Task { await uninstallHelper() }
                                    } label: {
                                        Text(String(localized: "Uninstall Helper Tool"))
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    Button {
                                        Task { await installHelper() }
                                    } label: {
                                        Text(String(localized: "Install Helper Tool"))
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            
                            if let statusMessage = statusMessage {
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            Text(String(localized: "The privileged helper tool is required to manage global launch daemons under /Library/LaunchDaemons with root authority."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                        .gridCellAnchor(.topLeading)
                    }
                }
                Spacer()
            }
            .padding(24)
            .tabItem {
                Label(String(localized: "Helper Tool"), systemImage: "lock.shield")
            }
            
            // Terminal Settings Tab
            VStack(alignment: .leading, spacing: 0) {
                Grid(alignment: .top, horizontalSpacing: 12, verticalSpacing: 16) {
                    GridRow {
                        Text(String(localized: "Console Theme:"))
                            .gridCellAnchor(.topTrailing)
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        
                        HStack(spacing: 12) {
                            ThemePreviewButton(
                                themeName: "classicGreen",
                                displayName: String(localized: "Green"),
                                bgColor: .black,
                                fgColor: .green,
                                isSelected: terminalTheme == "classicGreen"
                            ) {
                                terminalTheme = "classicGreen"
                            }
                            
                            ThemePreviewButton(
                                themeName: "monokai",
                                displayName: "Monokai",
                                bgColor: Color(red: 0.16, green: 0.16, blue: 0.15),
                                fgColor: Color(red: 0.98, green: 0.15, blue: 0.45),
                                isSelected: terminalTheme == "monokai"
                            ) {
                                terminalTheme = "monokai"
                            }
                            
                            ThemePreviewButton(
                                themeName: "ocean",
                                displayName: String(localized: "Ocean"),
                                bgColor: Color(red: 0.05, green: 0.12, blue: 0.22),
                                fgColor: Color(red: 0.2, green: 0.8, blue: 1.0),
                                isSelected: terminalTheme == "ocean"
                            ) {
                                terminalTheme = "ocean"
                            }
                            
                            ThemePreviewButton(
                                themeName: "classicWhite",
                                displayName: String(localized: "White"),
                                bgColor: .white,
                                fgColor: .black,
                                isSelected: terminalTheme == "classicWhite"
                            ) {
                                terminalTheme = "classicWhite"
                            }
                        }
                        .gridCellAnchor(.topLeading)
                    }
                    
                    GridRow {
                        Text(String(localized: "Font Size:"))
                            .gridCellAnchor(.topTrailing)
                            .fontWeight(.medium)
                            .padding(.top, 2)
                        
                        HStack(spacing: 12) {
                            Slider(value: $terminalFontSize, in: 10.0...24.0, step: 1.0)
                                .frame(width: 160)
                            
                            Text(String(format: "%.0f pt", terminalFontSize))
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 45, alignment: .trailing)
                            
                            Stepper("", value: $terminalFontSize, in: 10.0...24.0, step: 1.0)
                                .labelsHidden()
                        }
                        .gridCellAnchor(.topLeading)
                    }
                }
                Spacer()
            }
            .padding(24)
            .tabItem {
                Label(String(localized: "Terminal"), systemImage: "terminal")
            }
        }
        .frame(width: 580, height: 300)
        .onAppear {
            refreshHelperStatus()
        }
        .onReceive(timer) { _ in
            refreshHelperStatus()
        }
    }
    
    private var statusColor: Color {
        switch helperStatus {
        case .enabled: return .green
        case .requiresApproval: return .orange
        case .notFound, .notRegistered: return .red
        @unknown default: return .gray
        }
    }
    
    private var statusText: String {
        switch helperStatus {
        case .enabled: return String(localized: "Active")
        case .notFound: return String(localized: "Not Found")
        case .notRegistered: return String(localized: "Not Registered")
        case .requiresApproval: return String(localized: "Requires Approval")
        @unknown default: return String(localized: "Unknown")
        }
    }
    
    private func refreshHelperStatus() {
        helperStatus = XPCClient.shared.helperStatus
    }
    
    private func installHelper() async {
        isProcessing = true
        statusMessage = nil
        defer { isProcessing = false }
        
        do {
            try XPCClient.shared.registerHelper()
            refreshHelperStatus()
            statusMessage = String(localized: "Helper tool registered successfully.")
        } catch {
            statusMessage = String(localized: "Failed to register helper: \(error.localizedDescription)")
        }
    }
    
    private func uninstallHelper() async {
        isProcessing = true
        statusMessage = nil
        defer { isProcessing = false }
        
        do {
            try await XPCClient.shared.unregisterHelper()
            refreshHelperStatus()
            statusMessage = String(localized: "Helper tool unregistered successfully.")
        } catch {
            statusMessage = String(localized: "Failed to unregister helper: \(error.localizedDescription)")
        }
    }
}

// MARK: - Subviews

struct ThemePreviewButton: View {
    let themeName: String
    let displayName: String
    let bgColor: Color
    let fgColor: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(bgColor)
                    .frame(width: 56, height: 38)
                    .overlay(
                        Text(">_")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(fgColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: isSelected ? 2.5 : 1)
                    )
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.2) : Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                Text(displayName)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
