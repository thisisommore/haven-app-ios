//
//  QRCodeViews.swift
//  iOSExample
//

import SwiftUI
import UIKit
import AVFoundation

// MARK: - QR Scanner Constants
private let kScannerBlurRadius: CGFloat = 10
private let kScannerDarkAmount: CGFloat = 0.5

struct QRData: Identifiable {
    let id = UUID()
    let token: Int64
    let pubKey: Data
    let codeset: Int
}

// MARK: - QR Code Generator
func generateQRCode(from string: String) -> UIImage? {
    let data = string.data(using: .ascii)
    if let filter = CIFilter(name: "CIQRCodeGenerator") {
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        if let output = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledOutput = output.transformed(by: transform)
            let context = CIContext()
            if let cgImage = context.createCGImage(scaledOutput, from: scaledOutput.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
    }
    return nil
}

// MARK: - QR Code View
struct QRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let dmToken: Int64
    let pubKey: Data
    let codeset: Int
    
    private var url: String {
        let pubKeyBase64 = pubKey.base64EncodedString()
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "haven://dm?token=\(dmToken)&pubKey=\(pubKeyBase64)&codeset=\(codeset)"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let qrImage = generateQRCode(from: url) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                }
                
                Text(url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                VStack(spacing: 12) {
                    Button {
                        shareLink()
                    } label: {
                        HStack {
                            Image(systemName: "link")
                            Text("Share Link")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.haven)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button {
                        shareQRImage()
                    } label: {
                        HStack {
                            Image(systemName: "qrcode")
                            Text("Share QR Code")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.haven.opacity(0.15))
                        .foregroundColor(.haven)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 24)
                
                // Warning notice
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                    
                    Text("This is permanent and cannot be revoked. Only share with people you trust.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }.tint(.haven)
                }.hiddenSharedBackground()
            }
        }
    }
    
    private func shareLink() {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        presentActivityVC(activityVC)
    }
    
    private func shareQRImage() {
        guard let qrImage = generateQRCode(from: url) else { return }
        let activityVC = UIActivityViewController(activityItems: [qrImage], applicationActivities: nil)
        presentActivityVC(activityVC)
    }
    
    private func presentActivityVC(_ activityVC: UIActivityViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - QR Code Scanner
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onCodeScanned: (String) -> Void
    var onShowMyQR: (() -> Void)? = nil
    @State private var isScanning = true
    @State private var showSuccess = false
    @State private var torchOn = false
    
    private var boxSize: CGFloat {
        min(max(UIScreen.w(85), 250), 350)
    }
    
    var body: some View {
        ZStack {
            CameraPreviewView(onCodeFound: { code in
                guard isScanning else { return }
                isScanning = false
                
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                withAnimation {
                    showSuccess = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    onCodeScanned(code)
                    dismiss()
                }
            })
            .ignoresSafeArea()
            
            // Blur and dark overlay with cutout and box frame
            GeometryReader { geometry in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                
                ZStack {
                    // Blur effect (reduced by half)
                    Rectangle()
                        .fill(.regularMaterial)
                        .opacity(0.9)
                    
                    // Dark tint
                    Color.black.opacity(kScannerDarkAmount)
                    
                    // Cutout
                    RoundedRectangle(cornerRadius: 16)
                        .frame(width: boxSize, height: boxSize)
                        .position(x: centerX, y: centerY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                
                // Box frame
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.haven, lineWidth: 3)
                    .frame(width: boxSize, height: boxSize)
                    .position(x: centerX, y: centerY)
                
                // Success checkmark
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.haven)
                        .position(x: centerX, y: centerY)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
            
            // Top buttons
            VStack {
                HStack {
                    // Flash button
                    Button {
                        torchOn.toggle()
                        toggleTorch(on: torchOn)
                        // Different haptics for on/off
                        if torchOn {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        } else {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    } label: {
                        Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(torchOn ? .yellow : .white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 24)
                    
                    Spacer()
                    
                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                }
                .padding(.top, 60)
                Spacer()
            }
            
            // Bottom section
            VStack {
                Spacer()
                Text("Scan QR Code")
                    .font(.headline)
                    .foregroundColor(.white)
                    .opacity(showSuccess ? 0 : 1)
                
                if showSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("User added!")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.haven)
                    .cornerRadius(20)
                    .padding(.top, 16)
                } else if let onShowMyQR = onShowMyQR {
                    Button {
                        dismiss()
                        onShowMyQR()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode")
                            Text("Show My QR")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.haven)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.bottom, 80)
        }
        .onDisappear {
            if torchOn {
                toggleTorch(on: false)
            }
        }
    }
    
    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewControllerRepresentable {
    let onCodeFound: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeFound: onCodeFound)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = CameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let onCodeFound: (String) -> Void
        
        init(onCodeFound: @escaping (String) -> Void) {
            self.onCodeFound = onCodeFound
        }
        
        func didFindCode(_ code: String) {
            onCodeFound(code)
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didFindCode(_ code: String)
}

class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: CameraViewControllerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasFoundCode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        
        self.captureSession = session
        self.previewLayer = preview
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasFoundCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }
        
        hasFoundCode = true
        delegate?.didFindCode(code)
    }
}
