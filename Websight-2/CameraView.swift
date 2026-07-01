//
//  CameraView.swift
//  Websight-2
//
//  Created by Evan Nemetz on 2/27/26.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Binding var detectedText: String
    @Binding var scanRegion: CGRect
    @Binding var zoomLevel: CGFloat
    var isPaused: Bool = false
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.scanRegion = scanRegion
        uiViewController.updateZoom(zoomLevel)
        
        // Pause or resume camera based on state
        if isPaused {
            uiViewController.pauseCamera()
        } else {
            uiViewController.resumeCamera()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(detectedText: $detectedText)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        @Binding var detectedText: String
        
        init(detectedText: Binding<String>) {
            _detectedText = detectedText
        }
        
        func didDetectText(_ text: String) {
            DispatchQueue.main.async {
                self.detectedText = text
            }
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didDetectText(_ text: String)
}

class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let textRecognizer = TextRecognitionService()
    private var videoDevice: AVCaptureDevice?
    
    var scanRegion: CGRect = .zero {
        didSet {
            textRecognizer.scanRegion = scanRegion
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get camera device")
            return
        }
        
        self.videoDevice = videoCaptureDevice
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            print("Failed to create video input")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = captureSession
        self.previewLayer = previewLayer
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
    
    func updateZoom(_ zoomFactor: CGFloat) {
        guard let device = videoDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Clamp zoom factor to device's allowed range
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
            let clampedZoom = max(1.0, min(zoomFactor, maxZoom))
            
            device.videoZoomFactor = clampedZoom
            device.unlockForConfiguration()
        } catch {
            print("Failed to update zoom: \(error)")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
    
    func pauseCamera() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }
    
    func resumeCamera() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        textRecognizer.recognizeText(in: pixelBuffer) { [weak self] recognizedText in
            guard let self = self, !recognizedText.isEmpty else { return }
            self.delegate?.didDetectText(recognizedText)
        }
    }
}
