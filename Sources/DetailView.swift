import AppKit
import SwiftUI

struct DetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let wallpaper: Wallpaper
    @State private var filters: ImageFilters
    @State private var closeMonitor: Any?

    init(wallpaper: Wallpaper, filters: ImageFilters) {
        self.wallpaper = wallpaper
        _filters = State(initialValue: filters)
    }

    var body: some View {
        let busy = model.busyIDs.contains(wallpaper.id)
        let favorite = model.isFavorite(wallpaper)

        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(url: wallpaper.previewURL, filters: filters)
                .frame(width: 980, height: 560)
                .overlay(alignment: .topTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.ui(12, .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 30, height: 30)
                            .background(Palette.paper.opacity(0.85))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .pointingHand()
                    .help("Fechar")
                    .padding(14)
                }

            DetailFilters(filters: $filters)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(wallpaper.title)
                        .font(.display(40, weight: 850))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(credit)
                        .font(.ui(13))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                    Link(destination: wallpaper.pageURL) {
                        HStack(spacing: 4) {
                            Text("Ver no \(wallpaper.sourceName)")
                            Image(systemName: "arrow.up.right")
                                .font(.ui(10, .semibold))
                        }
                        .font(.label)
                        .foregroundStyle(Palette.ink)
                        .underline()
                    }
                    .pointingHand()
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 14) {
                    HStack(spacing: 10) {
                        Button {
                            model.toggleFavorite(wallpaper)
                        } label: {
                            Image(systemName: favorite ? "heart.fill" : "heart")
                        }
                        .buttonStyle(InkButtonStyle(prominent: false))
                        .help(favorite ? "Remover das salvas" : "Salvar")
                        Button {
                            Task { await model.apply(wallpaper, filters: filters) }
                        } label: {
                            HStack(spacing: 8) {
                                if busy { ProgressView().controlSize(.small).tint(Palette.paper) }
                                Text("Usar como papel de parede")
                            }
                        }
                        .buttonStyle(InkButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .disabled(busy)
                    }
                    HStack(spacing: 12) {
                        Text("Baixar")
                            .font(.caption1)
                            .foregroundStyle(Palette.inkFaint)
                        ForEach(ExportSize.allCases) { size in
                            TextOption(title: size.title, selected: false) {
                                Task { await model.download(wallpaper, size: size, filters: filters) }
                            }
                            .disabled(busy)
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 980)
        .background(Palette.paper)
        .tint(Palette.ink)
        .onAppear {
            closeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard flags == .command, event.charactersIgnoringModifiers?.lowercased() == "w" else { return event }
                dismiss()
                return nil
            }
        }
        .task { _ = await model.withCredit(wallpaper) }
        .onDisappear {
            if let closeMonitor { NSEvent.removeMonitor(closeMonitor) }
            closeMonitor = nil
        }
    }

    private var credit: String {
        let known = model.credits[wallpaper.id] ?? wallpaper
        var parts = [known.author.isEmpty ? "Via \(known.sourceName)" : "Foto de \(known.author)", known.resolutionLabel]
        if !known.license.isEmpty { parts.insert(known.license, at: 1) }
        if filters.isActive { parts.append("com filtros") }
        return parts.joined(separator: " · ")
    }
}

struct DetailFilters: View {
    @Binding var filters: ImageFilters

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            InkSwitch(isOn: $filters.grayscale, label: "Preto e branco")
            Rectangle().fill(Palette.rule).frame(width: 1, height: 18)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Desfoque")
                    .font(.caption1)
                    .foregroundStyle(Palette.inkFaint)
                TextOption(title: "Nenhum", selected: filters.blur == 0) { filters.blur = 0 }
                ForEach([1, 2, 4, 6, 8, 10], id: \.self) { value in
                    TextOption(title: "\(value)", selected: filters.blur == value) { filters.blur = value }
                }
            }
            Spacer(minLength: 0)
            ClearFiltersButton { filters = ImageFilters() }
                .opacity(filters.isActive ? 1 : 0)
                .disabled(!filters.isActive)
                .animation(.easeOut(duration: 0.15), value: filters.isActive)
        }
        .frame(height: 30)
    }
}
