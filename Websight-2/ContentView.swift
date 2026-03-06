//
//  ContentView.swift
//  Websight-2
//
//  Created by Evan Nemetz on 2/27/26.
//

import SwiftUI
import AVFoundation
import EventKit
import EventKitUI
import MapKit
import SafariServices
import MessageUI
import CoreLocation
import SwiftData

struct ContentView: View {
    @AppStorage("openUrlsInApp") private var openUrlsInApp: Bool = false
    @AppStorage("openMapsInApp") private var openMapsInApp: Bool = false
    @AppStorage("openMailInApp") private var openMailInApp: Bool = false
    @State private var detectedText: String = "Point camera at text..."
    @State private var filteredData: String = "Point camera at text..."
    @State private var lastDetectedItem: DetectedItem? = nil
    @State private var cameraPermissionGranted = false
    @State private var scanRegion: CGRect = .zero
    @State private var detectionTimer: Timer? = nil
    @State private var zoomLevel: CGFloat = 1.0
    @State private var showZoomSlider = false
    @State private var rainbowGlowOpacity: Double = 0.3
    @State private var rainbowRotation: Double = 0.0
    @State private var scanAreaGlowOpacity: Double = 0.3
    @State private var lastProcessedText: String = ""
    @State private var showEventEditor = false
    @State private var eventToCreate: DetectedItem? = nil
    @State private var showPill1 = false
    @State private var showPill2 = false
    @State private var showPill3 = false
    @State private var displayedItem: DetectedItem? = nil // Separate state for display
    @State private var isSettingsVisible = false
    @State private var isHistoryVisible = false
    @State private var showSafari = false
    @State private var safariURL: URL?
    @State private var showMap = false
    @State private var mapItem: MKMapItem?
    @State private var showMailComposer = false
    @State private var mailRecipient: String?
    @State private var isCameraPaused = false
    
    @Environment(\.modelContext) private var modelContext
    
    
    // Data detector for URLs, emails, phone numbers, addresses, and dates
    private let dataDetector: NSDataDetector = {
        let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber, .address, .date]
        return try! NSDataDetector(types: types.rawValue)
    }()
    
    struct DetectedItem {
        let text: String
        let type: DetectedType
        let url: URL?
        let date: Date? // Store the date for calendar events
        let addressComponents: [String: Any]? // Store address components for MapKit
        
        enum DetectedType {
            case website, email, phone, address, date
            
            var icon: String {
                switch self {
                case .website: return "globe"
                case .email: return "envelope.fill"
                case .phone: return "phone.fill"
                case .address: return "mappin.and.ellipse"
                case .date: return "calendar"
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            if cameraPermissionGranted {
                CameraView(detectedText: $detectedText, scanRegion: $scanRegion, zoomLevel: $zoomLevel, isPaused: isCameraPaused)
                    .edgesIgnoringSafeArea(.all)
                    .onChange(of: detectedText) { oldValue, newValue in
                        filterImportantData(from: newValue)
                    }
                
                // Completely clear scan area with Liquid Glass background
                GeometryReader { geometry in
                    ZStack {
                        // Liquid Glass background (everywhere)
                        ZStack {
                            Color.black.opacity(0.15)
                        }
                        .glassEffect(.regular, in: .rect)
                        .mask(
                            Rectangle()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .frame(
                                            width: geometry.size.width * 0.85,
                                            height: geometry.size.height * 0.1
                                        )
                                        .blendMode(.destinationOut)
                                )
                        )
                        .ignoresSafeArea()
                        
                        // Glowing border around scan area
                        VStack {
                            Spacer()
                            
                            ZStack {
                                // Rainbow glow shadow - multiple layers for intensity (appears when text is detected)
                                ForEach(0..<3) { index in
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(lineWidth: 4)
                                        .foregroundStyle(
                                            AngularGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.7, blue: 0.7),   // Pastel red/pink
                                                    Color(red: 1.0, green: 0.85, blue: 0.7),  // Pastel orange
                                                    Color(red: 1.0, green: 1.0, blue: 0.7),   // Pastel yellow
                                                    Color(red: 0.7, green: 1.0, blue: 0.7),   // Pastel green
                                                    Color(red: 0.7, green: 0.85, blue: 1.0),  // Pastel blue
                                                    Color(red: 0.85, green: 0.7, blue: 1.0),  // Pastel purple
                                                    Color(red: 1.0, green: 0.7, blue: 0.7)    // Back to pastel red/pink
                                                ],
                                                center: .center,
                                                angle: .degrees(rainbowRotation)
                                            )
                                        )
                                        .frame(
                                            width: geometry.size.width * 0.85,
                                            height: geometry.size.height * 0.1
                                        )
                                        .blur(radius: CGFloat(8 + index * 6))
                                        .opacity(lastDetectedItem != nil ? scanAreaGlowOpacity : 0)
                                        .animation(.easeInOut(duration: 0.8), value: lastDetectedItem != nil)
                                }
                                
                                // Subtle white glow shadow - multiple layers (always visible)
                                ForEach(0..<2) { index in
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(lineWidth: 3)
                                        .foregroundStyle(Color.white)
                                        .frame(
                                            width: geometry.size.width * 0.85,
                                            height: geometry.size.height * 0.1
                                        )
                                        .blur(radius: CGFloat(6 + index * 8))
                                        .opacity(lastDetectedItem != nil ? 0 : scanAreaGlowOpacity * 0.8)
                                        .animation(.easeInOut(duration: 0.8), value: lastDetectedItem != nil)
                                }
                            }
                            .onAppear {
                                // Start rotation animation (shared with bottom button)
                                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                                    rainbowRotation = 360.0
                                }
                                // Pulsing glow animation
                                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                    scanAreaGlowOpacity = 0.9
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Instructions and settings button at the top
                        VStack {
                            ZStack {
                                // Centered instruction bubble
                            
                                // Settings button on the right
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        isHistoryVisible.toggle()
                                    }) {
                                        Image(systemName: "clock")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                            .padding(10)
                                    }
                                    .glassEffect(.clear.interactive(), in: .circle)
                                    
                                    Spacer()
                                    
                                    
                                    Text("Align text within the frame")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .glassEffect(.clear.interactive(), in: .capsule)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        isSettingsVisible.toggle()
                                    }) {
                                        Image(systemName: "gearshape.fill")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                            .padding(10)
                                    }
                                    .glassEffect(.clear.interactive(), in: .circle)
                                }
                                .padding(.trailing, 20)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 60)
                        
                        
                        // Zoom control below scan area
                        VStack(spacing: 10) {
                            Spacer()
                            
                            // The scan area placeholder (invisible, just for spacing)
                            Color.clear
                                .frame(
                                    width: geometry.size.width * 0.85,
                                    height: geometry.size.height * 0.1
                                )
                            
                            // Additional spacing between scan area and zoom button
                            Spacer()
                                .frame(height: 70)
                            
                            // Zoom button
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    showZoomSlider.toggle()
                                }
                            }) {
                                Image(systemName: showZoomSlider ? "minus.magnifyingglass" : "plus.magnifyingglass")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                            }
                            .glassEffect(.regular.interactive(), in: .circle)
                            
                            // Horizontal zoom slider (shows when toggled)
                            if showZoomSlider {
                                HStack(spacing: 15) {
                                    Image(systemName: "minus")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Slider(value: $zoomLevel, in: 1.0...5.0, step: 0.1)
                                        .tint(.white)
                                        .frame(maxWidth: 200)
                                    
                                    Image(systemName: "plus")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("\(String(format: "%.1f", zoomLevel))x")
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .frame(width: 35)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .glassEffect(.regular, in: .capsule)
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            Spacer()
                        }
                    }
                    .onAppear {
                        updateScanRegion(geometry: geometry)
                    }
                    .onChange(of: geometry.size) { oldSize, newSize in
                        updateScanRegion(geometry: geometry)
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    // Floating action pills (show automatically when text is detected)
                    if let item = displayedItem {
                        VStack(alignment: .leading, spacing: 12) {
                            // Primary action button
                            Button(action: {
                                if item.type == .date {
                                    // Show event editor for dates
                                    eventToCreate = item
                                    showEventEditor = true
                                } else if item.type == .address {
                                    // Handle address - check if user wants in-app map
                                    if openMapsInApp {
                                        openMapsInAppView(for: item)
                                    } else {
                                        openMapsExternal(for: item)
                                    }
                                } else {
                                    openDetectedItem(item)
                                }
                                clearDetection()
                            }) {
                                HStack {
                                    Image(systemName: actionIcon(for: item.type))
                                        .font(.body)
                                    Text(actionText(for: item.type))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .glassEffect(.clear.interactive(), in: .capsule)
                            .opacity(showPill1 ? 1 : 0)
                            .scaleEffect(showPill1 ? 1 : 0.8)
                            .animation(.easeOut(duration: 0.3), value: showPill1)
                            
                            // Copy button
                            Button(action: {
                                UIPasteboard.general.string = item.text
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                clearDetection()
                            }) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                        .font(.body)
                                    Text("Copy")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .glassEffect(.clear.interactive(), in: .capsule)
                            .opacity(showPill2 ? 1 : 0)
                            .scaleEffect(showPill2 ? 1 : 0.8)
                            .animation(.easeOut(duration: 0.3), value: showPill2)
                            
                            // Share button
                            Button(action: {
                                shareItem(item)
                                clearDetection()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.body)
                                    Text("Share")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .glassEffect(.clear.interactive(), in: .capsule)
                            .opacity(showPill3 ? 1 : 0)
                            .scaleEffect(showPill3 ? 1 : 0.8)
                            .animation(.easeOut(duration: 0.3), value: showPill3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                        .onAppear {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                showPill1 = true
                            }
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.05)) {
                                showPill2 = true
                            }
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                                showPill3 = true
                            }
                        }
                        .onDisappear {
                            showPill1 = false
                            showPill2 = false
                            showPill3 = false
                        }
                    }
                    
                    // Display detected data at the bottom with liquid glass effect
                    if let item = lastDetectedItem {
                        HStack {
                            Image(systemName: item.type.icon)
                                .font(.title3)
                                .foregroundStyle(.primary)
                            
                            Text(item.text.lowercased())
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .truncationMode(.tail)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .strokeBorder(.primary.opacity(0.3), lineWidth: 1.5)
                        )
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .background(
                            Capsule()
                                .fill(
                                    AngularGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.7, blue: 0.7),   // Pastel red/pink
                                            Color(red: 1.0, green: 0.85, blue: 0.7),  // Pastel orange
                                            Color(red: 1.0, green: 1.0, blue: 0.7),   // Pastel yellow
                                            Color(red: 0.7, green: 1.0, blue: 0.7),   // Pastel green
                                            Color(red: 0.7, green: 0.85, blue: 1.0),  // Pastel blue
                                            Color(red: 0.85, green: 0.7, blue: 1.0),  // Pastel purple
                                            Color(red: 1.0, green: 0.7, blue: 0.7)    // Back to pastel red/pink
                                        ],
                                        center: .center,
                                        angle: .degrees(rainbowRotation)
                                    )
                                )
                                .blur(radius: 8)
                                .opacity(rainbowGlowOpacity)
                                .padding(-8)
                                .animation(.easeInOut(duration: 0.5), value: rainbowGlowOpacity)
                        )
                        .onAppear {
                            // Pulsing glow for bottom button
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                rainbowGlowOpacity = 0.7
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    } else {
                        HStack {
                            Image(systemName: "text.viewfinder")
                                .font(.title3)
                                .foregroundStyle(.primary.opacity(0.7))
                            
                            Text(filteredData)
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.7))
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                    
                    Text("Camera access is required")
                        .font(.headline)
                    
                    Text("Please grant camera permission to detect text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Request Permission") {
                        requestCameraPermission()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .sheet(isPresented: $showEventEditor, onDismiss: {
            // Clear the event to create after dismissing
            eventToCreate = nil
        }) {
            if let event = eventToCreate {
                EventEditView(event: event, isPresented: $showEventEditor)
            }
        }
        .onChange(of: showEventEditor) { oldValue, newValue in
            isCameraPaused = newValue
        }
        .fullScreenCover(isPresented: $isSettingsVisible) {
            SettingsView()
        }
        .onChange(of: isSettingsVisible) { oldValue, newValue in
            isCameraPaused = newValue
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .onChange(of: showSafari) { oldValue, newValue in
            isCameraPaused = newValue
        }
        .sheet(isPresented: $showMap) {
            if let item = mapItem {
                MapView(mapItem: item)
            }
        }
        .onChange(of: showMap) { oldValue, newValue in
            isCameraPaused = newValue
        }
        .sheet(isPresented: $showMailComposer) {
            if let recipient = mailRecipient {
                MailComposerView(recipient: recipient)
            }
        }
        .onChange(of: showMailComposer) { oldValue, newValue in
            isCameraPaused = newValue
        }
        .sheet(isPresented: $isHistoryVisible) {
            HistoryView(
                openUrlsInApp: openUrlsInApp,
                openMapsInApp: openMapsInApp,
                openMailInApp: openMailInApp
            )
        }
        .onChange(of: isHistoryVisible) { oldValue, newValue in
            isCameraPaused = newValue
        }
    }
    
    private func actionText(for type: DetectedItem.DetectedType) -> String {
        switch type {
            case .website: return "Open in Safari"
            case .email: return "Send Email"
            case .phone: return "Call"
            case .address: return "Open in Maps"
            case .date: return "Add to Calendar"
        }
    }
    
    private func actionIcon(for type: DetectedItem.DetectedType) -> String {
        switch type {
            case .website: return "safari"
            case .email: return "envelope"
            case .phone: return "phone"
            case .address: return "map"
            case .date: return "calendar.badge.plus"
        }
    }
    
    private func shareItem(_ item: DetectedItem) {
        let activityVC = UIActivityViewController(
            activityItems: [item.text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            requestCameraPermission()
        default:
            cameraPermissionGranted = false
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermissionGranted = granted
            }
        }
    }
    
    private func filterImportantData(from text: String) {
        guard !text.isEmpty else {
            filteredData = "Point camera at text..."
            return
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = dataDetector.matches(in: text, options: [], range: range)
        
        if matches.isEmpty {
            filteredData = "No data detected"
            return
        }
        
        // Get the first match and create a DetectedItem
        if let firstMatch = matches.first,
           let textRange = Range(firstMatch.range, in: text) {
            let matchedText = String(text[textRange])
            
            // Skip if we just processed this exact text
            guard matchedText != lastProcessedText else {
                return
            }
            
            var detectedItem: DetectedItem?
            
            switch firstMatch.resultType {
            case .link:
                if let url = firstMatch.url {
                    if url.scheme == "mailto" {
                        detectedItem = DetectedItem(text: matchedText, type: .email, url: url, date: nil, addressComponents: nil)
                    } else {
                        detectedItem = DetectedItem(text: matchedText, type: .website, url: url, date: nil, addressComponents: nil)
                    }
                }
            case .phoneNumber:
                if let phoneNumber = firstMatch.phoneNumber {
                    // Clean the phone number but preserve + for international numbers
                    let cleanedNumber = phoneNumber
                        .replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "(", with: "")
                        .replacingOccurrences(of: ")", with: "")
                        .replacingOccurrences(of: "-", with: "")
                    let phoneURL = URL(string: "tel:\(cleanedNumber)")
                    detectedItem = DetectedItem(text: matchedText, type: .phone, url: phoneURL, date: nil, addressComponents: nil)
                }
            case .address:
                // Store address components for MapKit
                let addressDict = firstMatch.addressComponents as? [String: Any]
                
                // Create Maps URL for external opening
                let encodedAddress = matchedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let mapsURL = URL(string: "http://maps.apple.com/?q=\(encodedAddress)")
                detectedItem = DetectedItem(text: matchedText, type: .address, url: mapsURL, date: nil, addressComponents: addressDict)
            case .date:
                if let date = firstMatch.date {
                    // Format the date nicely for display
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    let formattedDate = formatter.string(from: date)
                    
                    detectedItem = DetectedItem(text: formattedDate, type: .date, url: nil, date: date, addressComponents: nil)
                }
            default:
                break
            }
            
            if let item = detectedItem {
                // This is a new detection
                lastDetectedItem = item
                displayedItem = item // Set the displayed item
                filteredData = item.text
                
                // Save to history
                saveToHistory(text: item.text, type: item.type.description)
                
                // Store the matched text for comparison (not the formatted text for dates)
                lastProcessedText = matchedText
                
                // Haptic feedback for detection
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Reset the timer
                detectionTimer?.invalidate()
                detectionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    DispatchQueue.main.async {
                        // Animate pills out
                        withAnimation(.easeOut(duration: 0.3)) {
                            showPill3 = false
                            rainbowGlowOpacity = 0.0
                        }
                        withAnimation(.easeOut(duration: 0.3).delay(0.05)) {
                            showPill2 = false
                        }
                        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                            showPill1 = false
                        }
                        
                        // Then remove the detected items after animations complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            lastDetectedItem = nil
                            displayedItem = nil
                            filteredData = "Point camera at text..."
                            // Clear lastProcessedText a bit later to ensure clean state
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                lastProcessedText = ""
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func openDetectedItem(_ item: DetectedItem) {
        guard let url = item.url else { return }
        
        // Open websites in-app if user preference is enabled
        if item.type == .website && openUrlsInApp {
            safariURL = url
            showSafari = true
        } else if item.type == .email && openMailInApp {
            // Check if device can send mail before showing composer
            if MFMailComposeViewController.canSendMail() {
                // Pause camera immediately
                isCameraPaused = true
                
                // Extract email address from mailto: URL
                let emailAddress = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                mailRecipient = emailAddress
                showMailComposer = true
            } else {
                // Fall back to opening Mail app externally
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        } else {
            // Open externally (for phone, or when preference is off)
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openMapsInAppView(for item: DetectedItem) {
        // Geocode the address and show in-app map view
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(item.text) { placemarks, error in
            if let placemark = placemarks?.first {
                let mkPlacemark = MKPlacemark(placemark: placemark)
                let mkMapItem = MKMapItem(placemark: mkPlacemark)
                mkMapItem.name = item.text
                
                // Show in-app map
                mapItem = mkMapItem
                showMap = true
            } else {
                // If geocoding fails, open with URL externally
                if let url = item.url {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    private func openMapsExternal(for item: DetectedItem) {
        // Open in external Maps app
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
                // If geocoding fails, open with URL
                if let url = item.url {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    private func clearDetection() {
        detectionTimer?.invalidate()
        detectionTimer = nil
        lastProcessedText = "" // Clear this so the same text can be detected again
        
        // Animate pills out first
        withAnimation(.easeOut(duration: 0.3)) {
            showPill3 = false
            rainbowGlowOpacity = 0.0
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.05)) {
            showPill2 = false
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
            showPill1 = false
        }
        
        // Then remove BOTH the detected item AND displayed item after animations complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            lastDetectedItem = nil
            displayedItem = nil
            filteredData = "Point camera at text..."
        }
    }
    
    private func updateScanRegion(geometry: GeometryProxy) {
        // Calculate the scan region in normalized coordinates (0-1)
        // The scan box is centered horizontally and vertically
        let boxWidthPercent: CGFloat = 0.85
        let boxHeightPercent: CGFloat = 0.1
        
        // Center the box (SwiftUI uses top-left origin)
        let boxX = (1.0 - boxWidthPercent) / 2.0
        let boxY = (1.0 - boxHeightPercent) / 2.0
        
        scanRegion = CGRect(
            x: boxX,
            y: boxY,
            width: boxWidthPercent,
            height: boxHeightPercent
        )
    }
    
    private func saveToHistory(text: String, type: String) {
        // Create and insert new history record
        let newHistory = History(text: text, type: type)
        modelContext.insert(newHistory)
        
        // Fetch all history sorted by timestamp (newest first)
        let descriptor = FetchDescriptor<History>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        // Get all records and keep only 5 most recent
        if let allHistory = try? modelContext.fetch(descriptor),
           allHistory.count > 5 {
            // Delete oldest records (everything after first 5)
            allHistory.dropFirst(5).forEach { modelContext.delete($0) }
        }
        
        // Save changes
        try? modelContext.save()
    }
}

// MARK: - Mail Composer View
struct MailComposerView: View {
    let recipient: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        MailComposeViewController(recipient: recipient, dismiss: dismiss)
            .ignoresSafeArea()
    }
}

struct MailComposeViewController: UIViewControllerRepresentable {
    let recipient: String
    let dismiss: DismissAction
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        
        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

// MARK: - Map View
struct MapView: View {
    let mapItem: MKMapItem
    @Environment(\.dismiss) var dismiss
    @State private var region: MKCoordinateRegion
    @State private var route: MKRoute?
    @State private var showDirections = false
    @State private var locationManager = LocationManager()
    @State private var showLocationAlert = false
    
    init(mapItem: MKMapItem) {
        self.mapItem = mapItem
        
        let coordinate = mapItem.placemark.coordinate
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MapViewRepresentable(
                    region: $region,
                    destination: mapItem.placemark.coordinate,
                    route: route,
                    showDirections: showDirections
                )
                
                // Show directions info overlay when route is calculated
                if showDirections, let route = route {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Distance: \(formatDistance(route.distance))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Time: \(formatTime(route.expectedTravelTime))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Hide Route") {
                                withAnimation {
                                    showDirections = false
                                    self.route = nil
                                    // Reset region to destination
                                    region = MKCoordinateRegion(
                                        center: mapItem.placemark.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                    }
                }
            }
            .navigationTitle(mapItem.name ?? "Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !showDirections {
                            Button(action: {
                                requestLocationAndCalculateDirections()
                            }) {
                                Label("Show Directions", systemImage: "arrow.triangle.turn.up.right.circle")
                            }
                        }
                        
                        Button(action: {
                            // Open in external Maps app with directions
                            mapItem.openInMaps(launchOptions: [
                                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                            ])
                        }) {
                            Label("Directions in Maps", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        }
                        
                        Button(action: {
                            // Open in external Maps app without directions
                            mapItem.openInMaps()
                        }) {
                            Label("Open in Maps", systemImage: "map")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Location Access Required", isPresented: $showLocationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } message: {
            Text("Location access is needed to show directions. Please enable location services in Settings.")
        }
        .onAppear {
            // Request location permission when view appears if not already determined
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            }
        }
    }
    
    private func requestLocationAndCalculateDirections() {
        // Check location authorization status
        let status = locationManager.authorizationStatus
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            calculateDirections()
        } else if status == .notDetermined {
            // Request permission
            locationManager.requestPermission()
            // Wait a bit for the permission dialog, then check again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if locationManager.authorizationStatus == .authorizedWhenInUse || 
                   locationManager.authorizationStatus == .authorizedAlways {
                    calculateDirections()
                }
            }
        } else {
            // Permission denied - show alert
            showLocationAlert = true
        }
    }
    
    private func calculateDirections() {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapItem
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let route = response?.routes.first {
                self.route = route
                
                // Adjust region to show entire route
                let rect = route.polyline.boundingMapRect
                let inset = rect.size.width * 0.1
                let region = MKCoordinateRegion(
                    MKMapRect(
                        x: rect.origin.x - inset,
                        y: rect.origin.y - inset,
                        width: rect.size.width + inset * 2,
                        height: rect.size.height + inset * 2
                    )
                )
                
                withAnimation {
                    self.region = region
                    showDirections = true
                }
            }
        }
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let miles = distance / 1609.34
        if miles < 0.1 {
            return String(format: "%.0f ft", distance * 3.281)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

// UIViewRepresentable for the actual MapKit view with route overlay
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let destination: CLLocationCoordinate2D
    let route: MKRoute?
    let showDirections: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // Add destination pin
        let annotation = MKPointAnnotation()
        annotation.coordinate = destination
        mapView.addAnnotation(annotation)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        // Update route overlay
        mapView.removeOverlays(mapView.overlays)
        if showDirections, let route = route {
            mapView.addOverlay(route.polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Make MKPointAnnotation identifiable for the map
extension MKPointAnnotation: Identifiable {
    public var id: String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = .systemBlue
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - EventKit Integration
struct EventEditView: UIViewControllerRepresentable {
    let event: ContentView.DetectedItem
    @Binding var isPresented: Bool
    @State private var eventStore = EKEventStore()
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let eventEditVC = EKEventEditViewController()
        eventEditVC.eventStore = eventStore
        eventEditVC.editViewDelegate = context.coordinator
        
        // Create a new event immediately with the detected date
        if let eventDate = event.date {
            let newEvent = EKEvent(eventStore: eventStore)
            newEvent.title = "New Event"
            newEvent.startDate = eventDate
            
            // Set end date to 1 hour after start
            newEvent.endDate = eventDate.addingTimeInterval(3600)
            newEvent.calendar = eventStore.defaultCalendarForNewEvents
            
            eventEditVC.event = newEvent
        }
        
        // Request calendar access in the background
        Task {
            do {
                _ = try await eventStore.requestFullAccessToEvents()
            } catch {
                print("Calendar access error: \(error)")
            }
        }
        
        return eventEditVC
    }
    
    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {
        // No updates needed
    }
    
    class Coordinator: NSObject, EKEventEditViewDelegate {
        let parent: EventEditView
        
        init(_ parent: EventEditView) {
            self.parent = parent
        }
        
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            parent.isPresented = false
            
            if action == .saved {
                // Save the event
                if let eventToSave = controller.event {
                    do {
                        try controller.eventStore.save(eventToSave, span: .thisEvent)
                        
                        // Success haptic
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } catch {
                        print("Error saving event: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Location Manager
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus
    
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

extension ContentView.DetectedItem.DetectedType {
    var description: String {
        switch self {
        case .website: return "website"
        case .email: return "email"
        case .phone: return "phone"
        case .address: return "address"
        case .date: return "date"
        }
    }
}

#Preview {
    ContentView()
}
