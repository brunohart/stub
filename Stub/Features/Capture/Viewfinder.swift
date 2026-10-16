import SwiftUI
// AVFoundation is not yet annotated for Swift 6's concurrency checking; the capture session lives on its own queue.
@preconcurrency import AVFoundation
import Vision
import OSLog
import PhotosUI

/// The camera, held up to a ticket (ADR-025). Keep a stub opens here: the viewfinder full screen, four registration marks
/// framing where a ticket goes, and when Vision finds a ticket in the frame the marks spring onto its corners and ink in
/// orange, with a tap under the thumb: it has seen it. The shutter takes the photograph; the reader does the rest, as it
/// does for one from the library. A photograph from the library and typing it in are the two other ways in, at either
/// side of the shutter. A cinema foyer is dark, so the torch is one tap away.
///
/// The simulator has no camera: the viewfinder says so and offers the other two ways. In Debug, `-camera file` stands a
/// still photograph in for the camera, so the whole of it can be seen working there.
struct Viewfinder: View {
    let took: (CGImage) -> Void
    let library: (PhotosPickerItem) -> Void
    let type: () -> Void
    let cancel: () -> Void

    @State private var camera = Camera()
    @State private var pick: PhotosPickerItem?
    @State private var flash = false
    @State private var taking = false
    @State private var frozen: CGImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // The picture and the marks share the whole screen, so the marks land on the ticket where it shows.
            GeometryReader { full in
                ZStack(alignment: .topLeading) {
                    feed
                        .frame(width: full.size.width, height: full.size.height)
                        .clipped()
                        // The camera's picture: what is printed on a ticket in it is the ticket's, said by the line below
                        // once it is read (decision 005).
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Viewfinder")
                        .accessibilityAddTraits(.isImage)
                        .accessibilityIdentifier("artwork")
                    if camera.canTake {
                        RegistrationFrame(quad: camera.quad.map { $0.inView(full.size, image: camera.imageSize, fill: camera.fills) },
                                          rest: restingFrame(in: full.size), locked: camera.locked)
                            .allowsHitTesting(false)
                    }
                }
            }
            .ignoresSafeArea()
            // The light of the shutter: the frame goes to paper for an instant.
            Ink.paper.opacity(flash ? 0.85 : 0).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 0) {
                top
                Spacer()
                guidance
                    .padding(.bottom, 18)
                bench
            }
        }
        .task { await camera.start() }
        #if DEBUG || PERF
        // `-shutter`, with `-camera`: take the photograph a moment after the marks lock, as a thumb would.
        .task(id: camera.locked) {
            guard DebugDrive.wantsShutter, camera.locked, !taking else { return }
            try? await Task.sleep(for: .seconds(1.4))
            await shoot()
        }
        #endif
        .onDisappear { camera.stop() }
        .onChange(of: pick) { _, item in if let item { library(item) } }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: camera.locked) { _, now in now }
        .statusBarHidden()
    }

    @ViewBuilder
    private var feed: some View {
        if let frozen {
            Image(decorative: frozen, scale: 1).resizable().aspectRatio(contentMode: camera.fills ? .fill : .fit)
        } else {
            switch camera.state {
            case .running:
                CameraPreview(session: camera.session)
            case .still(let image):
                Image(decorative: image, scale: 1).resizable().scaledToFit()
            case .starting, .unavailable, .denied:
                Color(hex: 0x15120F)
            }
        }
    }

    /// Where the marks rest before a ticket is found: a ticket's shape, a little above the middle.
    private func restingFrame(in size: CGSize) -> CGRect {
        let w = size.width - 64
        let h = w / 1.75
        return CGRect(x: 32, y: size.height * 0.42 - h / 2, width: w, height: h)
    }

    private var top: some View {
        HStack {
            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Cancel")
            Spacer()
            if camera.hasTorch {
                Button { camera.torch.toggle() } label: {
                    Image(systemName: camera.torch ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 17, weight: .medium))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(camera.torch ? "Torch off" : "Torch on")
                .sensoryFeedback(.impact(weight: .light), trigger: camera.torch)
            }
        }
        .foregroundStyle(Ink.paper)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var guidance: some View {
        Text(sentence)
            .font(Type.words(16))
            .foregroundStyle(Ink.paper)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 32)
            .shadow(color: .black.opacity(0.6), radius: 6)
            .contentTransition(.opacity)
            .animation(Motion.place, value: sentence)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var sentence: String {
        switch camera.state {
        case .unavailable: return "This phone has no camera to hold up to a ticket. Choose a photograph of it, or type it in."
        case .denied: return "Stub cannot use the camera. Settings › Stub › Camera lets it, or choose a photograph of the ticket."
        case .starting: return " "
        case .running, .still:
            return camera.locked ? "That is a ticket. Take it while it is still." : "Lay the stub flat and fit it inside the marks."
        }
    }

    /// The shutter in the middle, the library on the left, typing on the right, on a band of ink.
    private var bench: some View {
        HStack(alignment: .center) {
            PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                SideControl(symbol: "photo.on.rectangle.angled", title: "Photos")
            }
            .accessibilityHint("Choose a photograph of the ticket from your library.")
            Spacer()
            switch camera.state {
            case .denied:
                // A way back to the camera, where the person turned it off.
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: { Text("Open Settings") }
                .buttonStyle(.stub(.paper, tight: true))
            case .unavailable:
                EmptyView()
            default:
                Shutter(enabled: camera.canTake && !taking, locked: camera.locked) { Task { await shoot() } }
            }
            Spacer()
            Button(action: type) { SideControl(symbol: "keyboard", title: "Type it in") }
                .accessibilityHint("Fill the stub in by hand.")
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 10)
        .background(
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.55)], startPoint: .top, endPoint: .center)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func shoot() async {
        taking = true
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.06)) { flash = true }
            withAnimation(.easeIn(duration: 0.35).delay(0.06)) { flash = false }
        }
        guard let image = await camera.take() else {
            taking = false
            return
        }
        frozen = image
        camera.stop()
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 220))
        took(image)
    }
}

/// The library and typing, either side of the shutter: a mark over a word, in paper.
private struct SideControl: View {
    let symbol: String
    let title: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 21, weight: .regular)).frame(height: 26)
            Text(title).font(Type.words(13)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Ink.paper)
        .frame(minWidth: 72, minHeight: 64)
        .contentShape(Rectangle())
    }
}

/// The shutter: a paper disc in a ring of paper, as a camera's is. The ring takes the marks' orange when they have found the
/// ticket. Pressed, the disc goes in; let go, the photograph is taken.
private struct Shutter: View {
    let enabled: Bool
    let locked: Bool
    let act: () -> Void

    var body: some View {
        Button(action: act) {
            Circle().strokeBorder(locked ? Ink.orange : Ink.paper, lineWidth: 4)
                .frame(width: 78, height: 78)
                .animation(Motion.settle, value: locked)
        }
        .buttonStyle(ShutterPress())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel("Take the photograph")
    }

    private struct ShutterPress: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            let down = configuration.isPressed
            ZStack {
                configuration.label
                Circle().fill(Ink.paper).frame(width: 62, height: 62)
                    .scaleEffect(down ? 0.86 : 1)
            }
            .animation(down ? .spring(response: 0.14, dampingFraction: 0.9) : .spring(response: 0.36, dampingFraction: 0.6), value: down)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: down) { _, now in now }
            .contentShape(Circle())
        }
    }
}

/// Four registration marks, the press's own (ADR-016): at rest they frame where a ticket goes; on a ticket they spring to
/// its corners, each a corner of the print, and ink in orange.
private struct RegistrationFrame: View {
    /// The ticket's corners in the view, top-left, top-right, bottom-right, bottom-left; `nil` until one is seen.
    let quad: [CGPoint]?
    let rest: CGRect
    let locked: Bool

    var body: some View {
        let corners = quad.flatMap { $0.count == 4 ? $0 : nil } ?? [CGPoint(x: rest.minX, y: rest.minY), CGPoint(x: rest.maxX, y: rest.minY),
                               CGPoint(x: rest.maxX, y: rest.maxY), CGPoint(x: rest.minX, y: rest.maxY)]
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Mark(corner: i, locked: locked)
                    .position(corners[i])
            }
        }
        .animation(.interpolatingSpring(stiffness: 210, damping: 19), value: corners.map(\.x) + corners.map(\.y))
        .animation(Motion.stamp, value: locked)
    }

    private struct Mark: View {
        let corner: Int
        let locked: Bool

        var body: some View {
            ZStack {
                arm.stroke(Ink.orange.opacity(locked ? 0.95 : 0.7), style: StrokeStyle(lineWidth: 3, lineCap: .square))
                    .offset(x: locked ? 0 : 2, y: locked ? 0 : 2.5)
                arm.stroke(locked ? Ink.orange : Ink.paper, style: StrokeStyle(lineWidth: 3, lineCap: .square))
            }
            .frame(width: 28, height: 28)
            .rotationEffect(.degrees(Double(corner) * 90))
            .scaleEffect(locked ? 1.12 : 1)
            .shadow(color: .black.opacity(0.4), radius: 3)
        }

        /// The top-left mark: an L, its corner at the centre of the frame, turned for the others.
        private var arm: Path {
            Path { p in
                p.move(to: CGPoint(x: 14, y: 28))
                p.addLine(to: CGPoint(x: 14, y: 14))
                p.addLine(to: CGPoint(x: 28, y: 14))
            }
        }
    }
}

/// The capture session's layer, filling the screen.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.layer.session = session
        view.layer.videoGravity = .resizeAspectFill
        view.layer.connection?.videoRotationAngle = 90
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        override var layer: AVCaptureVideoPreviewLayer { super.layer as! AVCaptureVideoPreviewLayer }
    }
}

/// A ticket's corners as Vision found them: in the upright picture, as fractions of it, origin top-left.
struct Quad: Equatable, Sendable {
    var topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint

    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft; self.topRight = topRight; self.bottomRight = bottomRight; self.bottomLeft = bottomLeft
    }

    /// From Vision's observation, whose origin is the bottom-left.
    init(_ o: VNRectangleObservation) {
        func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
        self.init(topLeft: flip(o.topLeft), topRight: flip(o.topRight), bottomRight: flip(o.bottomRight), bottomLeft: flip(o.bottomLeft))
    }

    /// The corners where they show on screen: the picture fills the view and is cropped to it, as the preview is, or (a
    /// still standing in for the camera) fits inside it.
    func inView(_ view: CGSize, image: CGSize, fill: Bool = true) -> [CGPoint] {
        guard image.width > 0, image.height > 0 else { return [] }
        let scale = fill ? max(view.width / image.width, view.height / image.height) : min(view.width / image.width, view.height / image.height)
        let drawn = CGSize(width: image.width * scale, height: image.height * scale)
        let origin = CGPoint(x: (view.width - drawn.width) / 2, y: (view.height - drawn.height) / 2)
        return [topLeft, topRight, bottomRight, bottomLeft].map { CGPoint(x: origin.x + $0.x * drawn.width, y: origin.y + $0.y * drawn.height) }
    }

    /// How far two finds of a ticket are apart, as the most any corner moved.
    func distance(to other: Quad) -> CGFloat {
        zip([topLeft, topRight, bottomRight, bottomLeft], [other.topLeft, other.topRight, other.bottomRight, other.bottomLeft])
            .map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 1
    }
}

/// The camera and what it sees: the session, the photograph output, and a ticket found in the frames (ADR-025).
@MainActor @Observable
final class Camera {
    enum State: Equatable {
        case starting, running, unavailable, denied
        /// A still photograph standing in for the camera (Debug, `-camera`).
        case still(CGImage)
    }

    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "camera")

    private(set) var state: State = .starting
    /// Where the ticket is, smoothed, and whether it has held still long enough to be called found.
    private(set) var quad: Quad?
    private(set) var locked = false
    /// The upright picture's size, for placing the marks over it.
    private(set) var imageSize: CGSize = .zero
    private(set) var hasTorch = false
    var torch = false { didSet { engine.torch(torch) } }

    /// The live picture fills the screen; a still fits on it.
    var fills: Bool { if case .still = state { false } else { true } }

    var canTake: Bool {
        switch state {
        case .running, .still: true
        default: false
        }
    }

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private lazy var engine = Engine(session: session) { [weak self] quad, size in
        Task { @MainActor in self?.saw(quad, size: size) }
    }
    @ObservationIgnored private var steady = 0

    func start() async {
        #if DEBUG || PERF
        // A path on this Mac, or a fixture in the bundle by name (`-camera stub-7-thermal.png`), for the UI tests.
        if let path = DebugDrive.cameraFile,
           let data = FileManager.default.contents(atPath: path)
               ?? Bundle.main.url(forResource: path, withExtension: nil).flatMap({ try? Data(contentsOf: $0) }),
           let image = PlateImage.decode(data, maxPixelSize: 2400) {
            state = .still(image)
            imageSize = CGSize(width: image.width, height: image.height)
            let found = await Task.detached { Engine.find(in: image) }.value
            try? await Task.sleep(for: .milliseconds(700))
            if let found { saw(found, size: imageSize); saw(found, size: imageSize); saw(found, size: imageSize) }
            return
        }
        #endif
        // A phone with no camera is not asked for it.
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            state = .unavailable
            Self.log.info("Camera: none on this device")
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { state = .denied; return }
        case .denied, .restricted:
            state = .denied
            return
        default: break
        }
        hasTorch = device.hasTorch
        let started = await engine.configure(device)
        state = started ? .running : .unavailable
    }

    func stop() {
        torch = false
        engine.stop()
    }

    /// The photograph, upright, at the size the reader takes.
    func take() async -> CGImage? {
        if case .still(let image) = state { return image }
        guard let data = await engine.capture() else { return nil }
        return PlateImage.decode(data, maxPixelSize: PlateImage.intake)
    }

    /// A ticket found in a frame, or none. The marks follow it smoothly; three finds in a row within a few points of each
    /// other and it is locked.
    private func saw(_ found: Quad?, size: CGSize) {
        imageSize = size
        guard let found else {
            steady = 0
            if quad != nil { quad = nil }
            if locked { locked = false }
            return
        }
        if let quad, quad.distance(to: found) < 0.025 { steady += 1 } else { steady = 0 }
        quad = found
        let now = steady >= 2
        if now != locked { locked = now }
    }

    /// The session's own queue: AVFoundation's work off the main actor, Vision on the frames as they come.
    private final class Engine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
        let session: AVCaptureSession
        let seen: @Sendable (Quad?, CGSize) -> Void
        private let queue = DispatchQueue(label: "com.designedbybruno.stub.camera")
        private let photo = AVCapturePhotoOutput()
        private let frames = AVCaptureVideoDataOutput()
        private var device: AVCaptureDevice?
        private var lastLook = Date.distantPast
        private var photoTaken: CheckedContinuation<Data?, Never>?

        init(session: AVCaptureSession, seen: @escaping @Sendable (Quad?, CGSize) -> Void) {
            self.session = session
            self.seen = seen
        }

        func configure(_ device: AVCaptureDevice) async -> Bool {
            await withCheckedContinuation { done in
                queue.async { [self] in
                    self.device = device
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input),
                          session.canAddOutput(photo), session.canAddOutput(frames) else {
                        session.commitConfiguration()
                        done.resume(returning: false)
                        return
                    }
                    session.addInput(input)
                    session.addOutput(photo)
                    frames.alwaysDiscardsLateVideoFrames = true
                    frames.setSampleBufferDelegate(self, queue: queue)
                    session.addOutput(frames)
                    session.commitConfiguration()
                    session.startRunning()
                    done.resume(returning: session.isRunning)
                }
            }
        }

        func stop() {
            queue.async { [self] in if session.isRunning { session.stopRunning() } }
        }

        func torch(_ on: Bool) {
            queue.async { [self] in
                guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            }
        }

        func capture() async -> Data? {
            await withCheckedContinuation { done in
                queue.async { [self] in
                    photoTaken = done
                    let settings = AVCapturePhotoSettings()
                    if let connection = photo.connection(with: .video) { connection.videoRotationAngle = 90 }
                    photo.capturePhoto(with: settings, delegate: self)
                }
            }
        }

        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            let data = photo.fileDataRepresentation()
            queue.async { [self] in
                photoTaken?.resume(returning: data)
                photoTaken = nil
            }
        }

        /// Ten looks a second are plenty for marks that spring: the rest of the frames go by.
        func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard Date().timeIntervalSince(lastLook) > 0.1, let pixels = CMSampleBufferGetImageBuffer(buffer) else { return }
            lastLook = Date()
            let size = CGSize(width: CVPixelBufferGetHeight(pixels), height: CVPixelBufferGetWidth(pixels))
            let request = Self.request()
            try? VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .right).perform([request])
            seen(request.results?.first.map(Quad.init), size)
        }

        static func request() -> VNDetectRectanglesRequest {
            let request = VNDetectRectanglesRequest()
            request.minimumAspectRatio = 0.25
            request.maximumAspectRatio = 1
            request.minimumSize = 0.25
            request.quadratureTolerance = 22
            request.minimumConfidence = 0.6
            request.maximumObservations = 1
            return request
        }

        /// A ticket in a still photograph.
        static func find(in image: CGImage) -> Quad? {
            let request = request()
            try? VNImageRequestHandler(cgImage: image).perform([request])
            return request.results?.first.map(Quad.init)
        }
    }
}
