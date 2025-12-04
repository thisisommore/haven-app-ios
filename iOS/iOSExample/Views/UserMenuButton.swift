import SwiftUI
import UIKit

// MARK: - QR Scanner Constants
private let kScannerBlurRadius: CGFloat = 10
private let kScannerDarkAmount: CGFloat = 0.5

struct UserMenuButton: UIViewRepresentable {
    let codename: String?
    let onExport: () -> Void
    let onShareQR: () -> Void
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.tintColor = UIColor(named: "Haven")
        
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let image = UIImage(systemName: "person.circle", withConfiguration: config)
        button.setImage(image, for: .normal)
        
        return button
    }
    
    func updateUIView(_ button: UIButton, context: Context) {
        let havenColor = UIColor(named: "Haven")
        
        let codenameAction = UIAction(
            title: codename ?? "Loading...",
            attributes: .disabled
        ) { _ in }
        
        let exportAction = UIAction(
            title: "Export",
            image: UIImage(systemName: "square.and.arrow.up")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onExport()
        }
        
        let shareQRAction = UIAction(
            title: "QR Code",
            image: UIImage(systemName: "qrcode")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onShareQR()
        }
        
        button.menu = UIMenu(children: [codenameAction, exportAction, shareQRAction])
    }
}

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

struct QRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    private let url = "https://example.com"
    
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

struct PlusMenuButton: UIViewRepresentable {
    let onJoinChannel: () -> Void
    let onCreateSpace: () -> Void
    let onScanQR: () -> Void
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.tintColor = UIColor(named: "Haven")
        
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let image = UIImage(systemName: "plus", withConfiguration: config)
        button.setImage(image, for: .normal)
        
        return button
    }
    
    func updateUIView(_ button: UIButton, context: Context) {
        let havenColor = UIColor(named: "Haven")
        
        let joinChannelAction = UIAction(
            title: "Join Channel",
            image: UIImage(systemName: "link")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onJoinChannel()
        }
        
        let createSpaceAction = UIAction(
            title: "Create Space",
            image: UIImage(systemName: "plus.square")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onCreateSpace()
        }
        
        let scanQRAction = UIAction(
            title: "Scan QR Code",
            image: UIImage(systemName: "qrcode.viewfinder")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onScanQR()
        }
        
        button.menu = UIMenu(children: [joinChannelAction, createSpaceAction, scanQRAction])
    }
}

// MARK: - QR Code Scanner

import AVFoundation

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onCodeScanned: (String) -> Void
    @State private var isScanning = true
    @State private var showSuccess = false
    @State private var torchOn = false
    
    private let boxSize: CGFloat = 250
    
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
                    // Blur effect
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
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
                    .stroke(showSuccess ? Color.green : Color.haven, lineWidth: 3)
                    .frame(width: boxSize, height: boxSize)
                    .position(x: centerX, y: centerY)
                
                // Success checkmark
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
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
            
            // Bottom text
            VStack {
                Spacer()
                Text(showSuccess ? "User added!" : "Scan QR Code")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 80)
            }
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

