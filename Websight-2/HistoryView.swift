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
    
    var body: some View {
        NavigationStack {
            List {
                if historyItems.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock",
                        description: Text("Your detected text history will appear here")
                    )
                } else {
                    ForEach(historyItems) { item in
                        Menu {
                            Button {
                                UIPasteboard.general.string = item.text
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            Button {
                                actOnItem(item)
                            } label: {
                                Label(actionText(for: item.type), systemImage: iconForType(item.type))
                            }
                            
                            Button {
                                shareItem(item)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.text)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                HStack {
                                    Image(systemName: iconForType(item.type))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(item.type.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(item.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.blue.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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
        }
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
    
    private func actOnItem(_ item: History) {
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
            urlString = "mailto:\(item.text)"
            if let url = URL(string: urlString) {
                if openMailInApp {
                    if MFMailComposeViewController.canSendMail() {
                        mailRecipient = item.text
                        showMailComposer = true
                    } else if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                } else if UIApplication.shared.canOpenURL(url) {
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
        default:
            return
        }
        
        if let url = URL(string: urlString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openMapsInApp(for item: History) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(item.text) { placemarks, error in
            if let placemark = placemarks?.first {
                let mkPlacemark = MKPlacemark(placemark: placemark)
                let mkMapItem = MKMapItem(placemark: mkPlacemark)
                mkMapItem.name = item.text
                
                mapItem = mkMapItem
                showMap = true
            } else {
                let encoded = item.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    private func openMapsExternal(for item: History) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(item.text) { placemarks, error in
            if let placemark = placemarks?.first {
                let mkPlacemark = MKPlacemark(placemark: placemark)
                let mapItem = MKMapItem(placemark: mkPlacemark)
                mapItem.name = item.text
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } else {
                let encoded = item.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    private func shareItem(_ item: History) {
        let activityVC = UIActivityViewController(
            activityItems: [item.text],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

#Preview {
    HistoryView(openUrlsInApp: true, openMapsInApp: true, openMailInApp: true)
        .modelContainer(for: History.self, inMemory: true)
}
