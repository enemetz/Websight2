//
//  HistoryView.swift
//  websight
//
//  Created by Evan Nemetz on 3/5/26.
//

import SwiftUI
import SwiftData
import MapKit
import SafariServices
import MessageUI
import CoreLocation
import EventKit
import EventKitUI

struct HistoryView: View {
    @Query(sort: \History.timestamp, order: .reverse) 
    private var historyItems: [History]
    
    let openUrlsInApp: Bool
    let openMapsInApp: Bool
    let openMailInApp: Bool
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: History?
    @State private var showActionSheet = false
    @State private var showSafari = false
    @State private var safariURL: URL?
    @State private var showMap = false
    @State private var mapItem: MKMapItem?
    @State private var showMailComposer = false
    @State private var mailRecipient: String?
    @State private var isLoading = false
    @State private var pressedButtonId: String?
    @State private var showCopiedConfirmation = false
    @State private var showEventEditor = false
    @State private var eventToAdd: EKEvent?
    @State private var eventStore: EKEventStore?
    @State private var shareItem: String?
    
    var body: some View {
        NavigationStack {
            List {
                if historyItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(historyItems) { item in
                        HistoryItemRow(
                            item: item,
                            pressedButtonId: $pressedButtonId,
                            isLoading: isLoading,
                            onAction: { actOnItem(item) },
                            onCopy: { copyItem(item) },
                            onShare: { shareItem(item) }
                        )
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                }
            }
            .sheet(isPresented: $showMap) {
                if let item = mapItem {
                    MapView(mapItem: item)
                }
            }
            .sheet(isPresented: $showMailComposer) {
                if let recipient = mailRecipient {
                    MailComposerView(recipient: recipient)
                }
            }
            .sheet(isPresented: $showEventEditor) {
                if let event = eventToAdd, let store = eventStore {
                    HistoryEventEditView(event: event, eventStore: store)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item])
            }
            .overlay {
                loadingOverlay
            }
            .overlay(alignment: .top) {
                copiedConfirmationBanner
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showCopiedConfirmation)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
            .onChange(of: showCopiedConfirmation) { oldValue, newValue in
                if newValue {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await MainActor.run {
                            showCopiedConfirmation = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No History",
            systemImage: "clock",
            description: Text("Your detected text history will appear here")
        )
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                
                ProgressView()
                    .tint(.white)
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    }
            }
            .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var copiedConfirmationBanner: some View {
        if showCopiedConfirmation {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.green)
                
                Text("Copied to Clipboard")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(999)
        }
    }
    
    private func copyItem(_ item: History) {
        UIPasteboard.general.string = item.text
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        showCopiedConfirmation = true
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "website": return "globe"
        case "email": return "envelope.fill"
        case "phone": return "phone.fill"
        case "address": return "mappin.and.ellipse"
        case "date": return "calendar"
        default: return "text.alignleft"
        }
    }
    
    private func actionText(for type: String) -> String {
        switch type.lowercased() {
        case "website": return "Open in Safari"
        case "email": return "Send Email"
        case "phone": return "Call"
        case "address": return "Open in Maps"
        case "date": return "Add to Calendar"
        default: return "Open"
        }
    }
    
    @ViewBuilder
    private func typeBadgeView(for item: History) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconForType(item.type))
                .font(.system(size: 11, weight: .semibold))
            Text(item.type.capitalized)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.blue.opacity(0.12)))
    }
    
    @ViewBuilder
    private func timestampView(for item: History) -> some View {
        Text(item.timestamp, style: .time)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
    }
    
    private func actOnItem(_ item: History) {
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Create appropriate URL based on type
        let urlString: String
        
        switch item.type.lowercased() {
        case "website":
            urlString = item.text.hasPrefix("http") ? item.text : "https://\(item.text)"
            if let url = URL(string: urlString) {
                if openUrlsInApp {
                    safariURL = url
                    showSafari = true
                } else if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
            return
        case "email":
            if openMailInApp && MFMailComposeViewController.canSendMail() {
                mailRecipient = item.text
                showMailComposer = true
            } else {
                urlString = "mailto:\(item.text)"
                if let url = URL(string: urlString),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
            return
        case "phone":
            let cleaned = item.text.filter { $0.isNumber || $0 == "+" }
            urlString = "tel:\(cleaned)"
        case "address":
            if openMapsInApp {
                openMapsInApp(for: item)
            } else {
                openMapsExternal(for: item)
            }
            return
        case "date":
            addToCalendar(text: item.text)
            return
        default:
            return
        }
        
        if let url = URL(string: urlString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openMapsInApp(for item: History) {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                guard let request = MKGeocodingRequest(addressString: item.text) else {
                    throw NSError(domain: "GeocodingError", code: 1, userInfo: nil)
                }
                
                // Perform geocoding off the main thread
                let mapItems = try await request.mapItems
                
                if let firstItem = mapItems.first {
                    await MainActor.run {
                        self.mapItem = firstItem
                        self.isLoading = false
                        // Small delay to ensure smooth transition
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(50))
                            self.showMap = true
                        }
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
                // If geocoding fails, fall back to URL-based opening
                let encoded = item.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                    await UIApplication.shared.open(url)
                }
            }
        }
    }
    
    private func openMapsExternal(for item: History) {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                guard let request = MKGeocodingRequest(addressString: item.text) else {
                    throw NSError(domain: "GeocodingError", code: 1, userInfo: nil)
                }
                
                // Perform geocoding off the main thread
                let mapItems = try await request.mapItems
                
                if let firstItem = mapItems.first {
                    _ = firstItem.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ])
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
                // If geocoding fails, fall back to URL-based opening
                let encoded = item.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                    await UIApplication.shared.open(url)
                }
            }
        }
    }
    
    private func shareItem(_ item: History) {
        // Use SwiftUI sheet presentation instead of UIKit
        shareItem = item.text
    }
    
    private func addToCalendar(text: String) {
        let store = EKEventStore()
        
        Task {
            do {
                let granted = try await store.requestFullAccessToEvents()
                guard granted else { return }
                
                await MainActor.run {
                    let event = EKEvent(eventStore: store)
                    event.title = "Event"
                    event.notes = text
                    
                    // Try to parse the date from text
                    if let parsedDate = parseDate(from: text) {
                        event.startDate = parsedDate
                        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: parsedDate) ?? parsedDate
                    } else {
                        event.startDate = Date()
                        event.endDate = Date().addingTimeInterval(3600)
                    }
                    
                    event.calendar = store.defaultCalendarForNewEvents
                    
                    eventStore = store
                    eventToAdd = event
                    showEventEditor = true
                }
            } catch {
                print("Calendar error: \(error)")
            }
        }
    }
    
    private func parseDate(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        // Try various common date formats
        let formats = [
            "MMMM d, yyyy",           // January 15, 2026
            "MMM d, yyyy",            // Jan 15, 2026
            "M/d/yyyy",               // 1/15/2026
            "MM/dd/yyyy",             // 01/15/2026
            "yyyy-MM-dd",             // 2026-01-15
            "EEEE, MMMM d, yyyy",     // Wednesday, January 15, 2026
            "EEE, MMM d, yyyy",       // Wed, Jan 15, 2026
            "d MMMM yyyy",            // 15 January 2026
            "d MMM yyyy",             // 15 Jan 2026
            "MM/dd/yy",               // 01/15/26
            "M/d/yy"                  // 1/15/26
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }
        
        // Try natural language parsing
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        if let match = detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let date = match.date {
            return date
        }
        
        return nil
    }
}

// MARK: - History Item Row
struct HistoryItemRow: View {
    let item: History
    @Binding var pressedButtonId: String?
    let isLoading: Bool
    let onAction: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Text content
                Text(item.text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Metadata row
                HStack(spacing: 12) {
                    typeBadgeView
                    Spacer()
                    timestampView
                }
            }
            .padding(16)
            
            // Divider with glass effect
            Rectangle()
                .fill(.secondary.opacity(0.2))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
            
            // Action buttons row
            HStack(spacing: 8) {
                primaryActionButton
                copyButton
                shareButton
            }
            .padding(12)
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thickMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var primaryActionButton: some View {
        Button(action: onAction) {
            let isPrimaryPressed = pressedButtonId == "primary-\(item.id)"
            
            HStack(spacing: 6) {
                Image(systemName: iconForType(item.type))
                    .font(.system(size: 13, weight: .semibold))
                Text(actionText(for: item.type))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .glassEffect(.clear.interactive())
            .tint(.mint)
            // .shadow(color: .mint.opacity(0.25), radius: isPrimaryPressed ? 2 : 5, y: isPrimaryPressed ? 1 : 2)
            .scaleEffect(isPrimaryPressed ? 0.96 : 1.0)
        }
        .buttonStyle(LiquidGlassButtonStyle(id: "primary-\(item.id)", pressedId: $pressedButtonId))
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressedButtonId)
    }
    
    private var copyButton: some View {
        Button(action: onCopy) {
            let isCopyPressed = pressedButtonId == "copy-\(item.id)"
            
            Image(systemName: "doc.on.doc")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 50, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .tint(.mint)
        .buttonStyle(LiquidGlassButtonStyle(id: "copy-\(item.id)", pressedId: $pressedButtonId))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressedButtonId)
    }
    
    private var shareButton: some View {
        Button(action: onShare) {
            let isSharePressed = pressedButtonId == "share-\(item.id)"
            
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 50, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .tint(.mint)
        .buttonStyle(LiquidGlassButtonStyle(id: "share-\(item.id)", pressedId: $pressedButtonId))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressedButtonId)
    }
    
    @ViewBuilder
    private var typeBadgeView: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForType(item.type))
                .font(.system(size: 11, weight: .semibold))
            Text(item.type.capitalized)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.blue.opacity(0.12)))
    }
    
    @ViewBuilder
    private var timestampView: some View {
        Text(item.timestamp, style: .time)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "website": return "globe"
        case "email": return "envelope.fill"
        case "phone": return "phone.fill"
        case "address": return "mappin.and.ellipse"
        case "date": return "calendar"
        default: return "text.alignleft"
        }
    }
    
    private func actionText(for type: String) -> String {
        switch type.lowercased() {
        case "website": return "Open in Safari"
        case "email": return "Send Email"
        case "phone": return "Call"
        case "address": return "Open in Maps"
        case "date": return "Add to Calendar"
        default: return "Open"
        }
    }
}

// MARK: - Event Edit View
struct HistoryEventEditView: UIViewControllerRepresentable {
    let event: EKEvent
    let eventStore: EKEventStore
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.event = event
        controller.eventStore = eventStore
        controller.editViewDelegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }
    
    class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction
        
        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }
        
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

// MARK: - Liquid Glass Button Style
struct LiquidGlassButtonStyle: ButtonStyle {
    let id: String
    @Binding var pressedId: String?
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    pressedId = isPressed ? id : nil
                }
                
                if isPressed {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Make String identifiable for the sheet
extension String: Identifiable {
    public var id: String { self }
}

#Preview {
    HistoryView(openUrlsInApp: true, openMapsInApp: true, openMailInApp: true)
        .modelContainer(for: History.self, inMemory: true)
}
