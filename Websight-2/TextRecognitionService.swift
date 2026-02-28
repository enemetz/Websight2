//
//  TextRecognitionService.swift
//  Websight-2
//
//  Created by Evan Nemetz on 2/27/26.
//

import Vision
import CoreImage

class TextRecognitionService {
    private var lastProcessedTime = Date()
    private let processingInterval: TimeInterval = 0.5 // Process every 0.5 seconds
    
    var scanRegion: CGRect = .zero
    
    func recognizeText(in pixelBuffer: CVPixelBuffer, completion: @escaping (String) -> Void) {
        // Throttle requests to avoid overwhelming the system
        let now = Date()
        guard now.timeIntervalSince(lastProcessedTime) >= processingInterval else {
            return
        }
        lastProcessedTime = now
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            guard error == nil else {
                print("Text recognition error: \(error!.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            // Filter observations to only include those within the scan region
            let filteredObservations = observations.filter { observation in
                guard !self.scanRegion.isEmpty else { return true }
                
                // With .up orientation, Vision rotates the frame to match device orientation
                // The video frames are in landscape orientation, so we need to transform coordinates
                // Camera frame coordinates need rotation: swap x/y and adjust
                
                // Transform: UI portrait -> Camera landscape with .up orientation
                // rotated_x = 1 - UI_y - UI_height (because Vision uses bottom-left origin)
                // rotated_y = UI_x
                // rotated_width = UI_height
                // rotated_height = UI_width
                
                let rotatedRegion = CGRect(
                    x: 1.0 - self.scanRegion.origin.y - self.scanRegion.height,
                    y: self.scanRegion.origin.x,
                    width: self.scanRegion.height,
                    height: self.scanRegion.width
                )
                
                // Check if observation center is within region
                let centerX = observation.boundingBox.midX
                let centerY = observation.boundingBox.midY
                
                let isWithinX = centerX >= rotatedRegion.minX && centerX <= rotatedRegion.maxX
                let isWithinY = centerY >= rotatedRegion.minY && centerY <= rotatedRegion.maxY
                
                return isWithinX && isWithinY
            }
            
            let recognizedStrings = filteredObservations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let fullText = recognizedStrings.joined(separator: "\n")
            completion(fullText)
        }
        
        // Configure for accurate text recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Set orientation to handle the camera's landscape frames
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Failed to perform text recognition: \(error)")
            }
        }
    }
}
