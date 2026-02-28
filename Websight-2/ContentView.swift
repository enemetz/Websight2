//
//  ContentView.swift
//  Websight-2
//
//  Created by Evan Nemetz on 2/27/26.
//

import SwiftUI
import AVFoundation

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
    
    // Data detector for URLs, emails, phone numbers, and addresses
    private let dataDetector: NSDataDetector = {
        let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber, .address]
        return try! NSDataDetector(types: types.rawValue)
    }()
    
    struct DetectedItem {
        let text: String
        let type: DetectedType
        let url: URL?
        
        enum DetectedType {
            case website, email, phone, address
            
            var icon: String {
                switch self {
                case .website: return "globe"
                case .email: return "envelope.fill"
                case .phone: return "phone.fill"
                case .address: return "mappin.and.ellipse"
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
                        
                        // Subtle border around the clear scan area
                        VStack {
                            Spacer()
                            
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(
                                    width: geometry.size.width * 0.85,
                                    height: geometry.size.height * 0.1
                                )
                            
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
                    
                    // Display detected data at the bottom with liquid glass effect
                    if let item = lastDetectedItem {
                        Button(action: {
                            openDetectedItem(item)
                        }) {
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
                                
                                Image(systemName: "arrow.up.forward.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
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
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                rainbowGlowOpacity = 0.7
                            }
                            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                                rainbowRotation = 360.0
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
                .animation(.easeInOut(duration: 0.5), value: lastDetectedItem != nil)
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
            
            var detectedItem: DetectedItem?
            
            switch firstMatch.resultType {
            case .link:
                if let url = firstMatch.url {
                    if url.scheme == "mailto" {
                        detectedItem = DetectedItem(text: matchedText, type: .email, url: url)
                    } else {
                        detectedItem = DetectedItem(text: matchedText, type: .website, url: url)
                    }
                }
            case .phoneNumber:
                if let phoneNumber = firstMatch.phoneNumber {
                    let phoneURL = URL(string: "tel:\(phoneNumber.replacingOccurrences(of: " ", with: ""))")
                    detectedItem = DetectedItem(text: matchedText, type: .phone, url: phoneURL)
                }
            case .address:
                // Create Maps URL for address
                let encodedAddress = matchedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let mapsURL = URL(string: "http://maps.apple.com/?q=\(encodedAddress)")
                detectedItem = DetectedItem(text: matchedText, type: .address, url: mapsURL)
            default:
                break
            }
            
            if let item = detectedItem {
                lastDetectedItem = item
                filteredData = "\(item.type.icon) \(item.text)"
                
                // Reset the timer
                detectionTimer?.invalidate()
                detectionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    DispatchQueue.main.async {
                        // Fade out the rainbow glow
                        withAnimation(.easeOut(duration: 0.5)) {
                            rainbowGlowOpacity = 0.0
                        }
                        // Then remove the detected item after the fade completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            lastDetectedItem = nil
                            filteredData = "Point camera at text..."
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

#Preview {
    ContentView()
}
