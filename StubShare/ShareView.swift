import SwiftUI

/// The share sheet's one screen: what was handed over, as Stub will read it, and one stamp to send it. Parchment, the three
/// faces, the stamps (ADR-022). Nothing is filed here; the app's import sheet is where a ticket is kept.
struct ShareView: View {
    let model: ShareModel
    var finish: () -> Void
    var cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button("Cancel", action: cancel).buttonStyle(.stub(.quiet))
                Spacer()
                Text("Keep in Stub").font(Type.display(17)).foregroundStyle(Ink.ink)
                Spacer()
                // Balances Cancel so the title sits in the middle.
                Text("Cancel").font(Type.words(16)).padding(.horizontal, 4).hidden()
            }
            content
            Spacer(minLength: 0)
            footer
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Ink.paper.ignoresSafeArea())
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            HStack(spacing: 10) {
                ProgressView().tint(Ink.orange)
                Text("Opening it…").font(Type.words(15)).foregroundStyle(Ink.ink.opacity(0.75))
            }
        case .pass(let pass, _):
            PassPreview(pass: pass)
        case .page(let image, let kind, _):
            VStack(alignment: .leading, spacing: 12) {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 8, x: 3, y: 5)
                    .frame(maxWidth: .infinity)
                Label(kind == .pdf ? "The first page of the PDF. Stub reads it on the phone when you open it."
                                   : "A picture of the ticket. Stub reads it on the phone when you open it.",
                      systemImage: kind == .pdf ? "doc.richtext" : "rectangle.on.rectangle")
                    .font(Type.words(14)).foregroundStyle(Ink.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .failed(let why):
            Text(why).font(Type.words(16)).foregroundStyle(Ink.rust)
                .fixedSize(horizontal: false, vertical: true)
        case .sent:
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "checkmark").font(.system(size: 22, weight: .medium)).foregroundStyle(Ink.orange)
                Text("It is waiting in Stub. Open Stub to keep it.")
                    .font(Type.words(17)).foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .task {
                try? await Task.sleep(for: .seconds(1.3))
                finish()
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch model.state {
        case .pass, .page:
            Button { model.send() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down").font(.system(size: 14, weight: .medium))
                    Text("Send to Stub")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.stub(.ink))
            Text("Nothing leaves the phone. Stub files it when you keep it.")
                .font(Type.words(12)).foregroundStyle(Ink.grey)
        default:
            EmptyView()
        }
    }
}

/// A Wallet pass as Stub reads it: its strip, the film, the cinema, and the night's numbers in the mono.
private struct PassPreview: View {
    let pass: WalletPass

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let plate = pass.plate, let image = UIImage(data: plate) {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            Text(pass.ticket.title.isEmpty ? "A pass with no film on it" : pass.ticket.title)
                .font(Type.display(26)).tracking(Type.displayTracking(26)).foregroundStyle(Ink.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !pass.ticket.cinema.isEmpty {
                Text(pass.ticket.cinema).font(Type.words(16)).foregroundStyle(Ink.ink.opacity(0.8))
            }
            HStack(spacing: 18) {
                if let at = pass.ticket.at {
                    Text(at.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()))
                        .font(Type.numbers(13)).foregroundStyle(Ink.ink.opacity(0.75))
                }
                if !pass.ticket.seat.isEmpty {
                    Text(pass.ticket.seat).font(Type.numbers(13)).foregroundStyle(Ink.ink.opacity(0.75))
                }
                if !pass.ticket.screen.isEmpty {
                    Text(pass.ticket.screen).font(Type.words(13)).foregroundStyle(Ink.grey)
                }
            }
            Label("Read from the pass. No camera, no model.", systemImage: "wallet.pass")
                .font(Type.words(14)).foregroundStyle(Ink.ink.opacity(0.75))
        }
    }
}
