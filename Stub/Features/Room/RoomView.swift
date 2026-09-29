import SwiftUI
import RealityKit
import ARKit

/// "Put it on the table" (ADR-018). The card at its real size on a real surface, through the camera, lit by the room:
/// the room's light falls on the foil, and walking round it moves the film. The one view where the light is not the
/// phone's. Nothing leaves the phone; the camera feeds ARKit and nothing is recorded.
///
/// On a phone that cannot track the world (and in the simulator, which has no camera) there is no way in: the detail
/// never offers it. In Debug, `-room` opens it anyway on a table drawn in parchment, so the card can be seen built.
struct RoomView: View {
    let composition: Composition
    let back: EditionBack

    @Environment(\.dismiss) private var dismiss
    @State private var card: ModelEntity?
    @State private var failed = false
    @State private var placed = false

    /// Whether this phone can put the card on a table.
    static var isSupported: Bool { ARWorldTrackingConfiguration.isSupported }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoomSurface(card: card, placed: $placed)
                .ignoresSafeArea()
                .accessibilityLabel("The camera, with the edition of \(composition.copy.title) on the table")

            // A slip of parchment: the one italic line, and the way out.
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(line)
                    .font(Type.italic(17))
                    .foregroundStyle(Ink.navy)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(Motion.place, value: line)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Text("Done").font(Type.words(16)).foregroundStyle(Ink.ink)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Ink.paper, in: RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 3, y: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .statusBarHidden()
        .task {
            do {
                card = try await RoomCard.entity(for: composition, back: back)
            } catch {
                RoomCard.log.error("Room: the card could not be built: \(error.localizedDescription)")
                failed = true
            }
        }
    }

    private var line: String {
        if failed { return "The card would not set down. Try again from the detail." }
        if card == nil { return "Cutting the card…" }
        return placed ? "On the table. The light is the room's." : "Find a table and hold the phone over it."
    }
}

/// RealityKit's view of the room. On a phone that tracks the world: the camera, horizontal planes, environment
/// texturing so the foil reflects the room, the coaching overlay until a table is found, the card set on the first
/// table at its real size, then moved and turned with a finger. Elsewhere: no camera, a parchment table under one
/// light, the card lying on it.
private struct RoomSurface: UIViewRepresentable {
    let card: ModelEntity?
    @Binding var placed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(placed: $placed) }

    func makeUIView(context: Context) -> ARView {
        let tracks = RoomView.isSupported
        let view = ARView(frame: .zero, cameraMode: tracks ? .ar : .nonAR, automaticallyConfigureSession: false)
        view.renderOptions.insert(.disableMotionBlur)
        context.coordinator.view = view
        if tracks {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            configuration.environmentTexturing = .automatic
            view.session.run(configuration)
            let coaching = ARCoachingOverlayView()
            coaching.session = view.session
            coaching.goal = .horizontalPlane
            coaching.activatesAutomatically = true
            coaching.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(coaching)
            NSLayoutConstraint.activate([
                coaching.topAnchor.constraint(equalTo: view.topAnchor), coaching.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                coaching.leadingAnchor.constraint(equalTo: view.leadingAnchor), coaching.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:))))
        } else {
            context.coordinator.standIn(in: view)
        }
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        guard let card, context.coordinator.card == nil else { return }
        context.coordinator.set(card)
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var view: ARView?
        var card: ModelEntity?
        let placed: Binding<Bool>
        private var anchor: AnchorEntity?

        init(placed: Binding<Bool>) { self.placed = placed }

        func set(_ card: ModelEntity) {
            guard let view else { return }
            self.card = card
            if RoomView.isSupported {
                // The first table big enough for the card. ARKit says when it has one; until then the coaching shows.
                let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.08, 0.12]))
                anchor.addChild(card)
                view.scene.addAnchor(anchor)
                self.anchor = anchor
                view.installGestures([.translation, .rotation], for: card)
                Task { @MainActor [weak self] in
                    while let anchor = self?.anchor, !anchor.isAnchored { try? await Task.sleep(for: .milliseconds(200)) }
                    self?.placed.wrappedValue = true
                }
            } else {
                anchor?.addChild(card)
                // Not during the representable's update: on the next turn of the run loop.
                Task { @MainActor [placed] in placed.wrappedValue = true }
            }
        }

        /// A tap on a table sets the card down there.
        @objc func tapped(_ tap: UITapGestureRecognizer) {
            guard let view, let card else { return }
            let point = tap.location(in: view)
            guard let hit = view.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal).first else { return }
            let moved = AnchorEntity(world: hit.worldTransform)
            card.removeFromParent()
            moved.addChild(card)
            if let anchor { view.scene.removeAnchor(anchor) }
            view.scene.addAnchor(moved)
            anchor = moved
            placed.wrappedValue = true
        }

        /// No camera: a parchment table a little below the eye, one light from the upper left as the house's shadows
        /// fall, and a camera looking down at where the card will lie.
        func standIn(in view: ARView) {
            view.environment.background = .color(UIColor(Ink.paper))
            // The default image-based light is a bright studio; the stand-in wants the dimmer room of an evening.
            view.environment.lighting.intensityExponent = -1.2
            let anchor = AnchorEntity(world: .zero)
            var table = PhysicallyBasedMaterial()
            table.baseColor = .init(tint: UIColor(Ink.paper))
            table.roughness = 0.85
            let surface = ModelEntity(mesh: .generatePlane(width: 0.6, depth: 0.6), materials: [table])
            anchor.addChild(surface)

            let light = DirectionalLight()
            light.light.intensity = 1400
            light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 0.6, depthBias: 1.2)
            light.look(at: .zero, from: [-0.22, 0.4, -0.18], relativeTo: nil)
            anchor.addChild(light)

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 36
            camera.look(at: [0, 0, 0.006], from: [0.02, 0.25, 0.15], relativeTo: nil)
            anchor.addChild(camera)
            view.scene.addAnchor(anchor)
            self.anchor = anchor
        }
    }
}
