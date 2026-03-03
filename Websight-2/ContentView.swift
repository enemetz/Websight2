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

struct ContentView: View {
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
    @State private var openMapsInApp = true // Toggle this for in-app vs external Maps
    @State private var showPill1 = false
    @State private var showPill2 = false
    @State private var showPill3 = false
    @State private var displayedItem: DetectedItem? = nil // Separate state for display
    
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
                CameraView(detectedText: $detectedText, scanRegion: $scanRegion, zoomLevel: $zoomLevel)
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
                        
                        // Instructions in glass bubble at the top
                        VStack {
                            Text("Align text within the frame")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .glassEffect(.regular, in: .capsule)
                            
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
                                    .foregroundStyle(.white)
                                    .padding(12)
                            }
                            .glassEffect(.regular.interactive(), in: .circle)
                            
                            // Horizontal zoom slider (shows when toggled)
                            if showZoomSlider {
                                HStack(spacing: 15) {
                                    Image(systemName: "minus")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                    
                                    Slider(value: $zoomLevel, in: 1.0...5.0, step: 0.1)
                                        .tint(.white)
                                        .frame(maxWidth: 200)
                                    
                                    Image(systemName: "plus")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                    
                                    Text("\(String(format: "%.1f", zoomLevel))x")
                                        .font(.caption)
                                        .foregroundStyle(.white)
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
                                } else if item.type == .address && openMapsInApp {
                                    // Open Maps in-app for addresses
                                    openMapsInApp(for: item)
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
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .glassEffect(.regular.interactive(), in: .capsule)
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
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .glassEffect(.regular.interactive(), in: .capsule)
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
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .glassEffect(.regular.interactive(), in: .capsule)
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
                                .foregroundStyle(.white)
                            
                            Text(item.text.lowercased())
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .truncationMode(.tail)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
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
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text(filteredData)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
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
                    let phoneURL = URL(string: "tel:\(phoneNumber.replacingOccurrences(of: " ", with: ""))")
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
        
        // Open the URL using UIApplication
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openMapsInApp(for item: DetectedItem) {
        // Fall back to geocoding the address string since MKPlacemark needs coordinates
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

#Preview {
    ContentView()
}
