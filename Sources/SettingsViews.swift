import ServiceManagement
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case automatic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Geral"
        case .automatic: "Automático"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape.fill"
        case .automatic: "bolt.fill"
        }
    }
}

struct SettingsView: View {
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $tab)
                .padding(.vertical, 14)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    switch tab {
                    case .general: GeneralSettings()
                    case .automatic: AutomaticSettings()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .inkScroller()
            }
        }
        .frame(width: 520, height: 500)
        .navigationTitle("Ajustes do Pane")
    }
}

struct SettingsTabBar: View {
    @Binding var selection: SettingsTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { item in
                let selected = item == selection
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) { selection = item }
                } label: {
                    Label(item.title, systemImage: item.icon)
                        .font(.ui(13, .semibold))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.primary.opacity(0.1))
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.04)))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

struct GeneralSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        SettingsSection("Inicialização") {
            LaunchAtLoginRow()
        }
        SettingsSection("Telas") {
            SettingsRow(
                icon: "display.2",
                tint: .blue,
                title: "Aplicar em todas as telas",
                subtitle: "Usa o mesmo papel de parede em todos os monitores."
            ) {
                Toggle("", isOn: $model.applyToAllScreens)
            }
        }
    }
}

struct AutomaticSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        SettingsSection("Troca automática") {
            SettingsRow(
                icon: "arrow.triangle.2.circlepath",
                tint: .green,
                title: "Trocar automaticamente",
                subtitle: model.nextRotation.map { "Próxima troca às \($0.formatted(date: .omitted, time: .shortened))." }
                    ?? "O papel de parede muda sozinho no intervalo escolhido."
            ) {
                Toggle("", isOn: $model.rotationEnabled)
            }
            SettingsDivider()
            SettingsRow(icon: "clock.fill", tint: .orange, title: "Intervalo") {
                Picker("", selection: $model.rotationMinutes) {
                    ForEach(AppModel.rotationOptions, id: \.self) { minutes in
                        Text(intervalLabel(minutes)).tag(minutes)
                    }
                }
            }
            .disabled(!model.rotationEnabled)
        }
        SettingsSection("Origem das fotos") {
            SettingsRow(icon: "shuffle", tint: .purple, title: "Sortear de") {
                Picker("", selection: $model.rotationSource) {
                    ForEach(RotationSource.allCases) { Text($0.title).tag($0) }
                }
            }
            if model.rotationSource == .category {
                SettingsDivider()
                SettingsRow(icon: model.rotationCategory.icon, tint: .pink, title: "Categoria") {
                    Picker("", selection: $model.rotationCategory) {
                        ForEach(WallCategory.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
        }
        .disabled(!model.rotationEnabled)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.ui(15, .bold))
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
        }
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider().padding(.leading, 46)
    }
}

struct SettingsRow<Accessory: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String?
    @ViewBuilder let accessory: Accessory

    init(icon: String, tint: Color, title: String, subtitle: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.ui(15, .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.ui(14, .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.ui(12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory
                .labelsHidden()
                .toggleStyle(.switch)
                .pickerStyle(.menu)
                .fixedSize()
        }
        .padding(.vertical, 12)
    }
}

func intervalLabel(_ minutes: Int) -> String {
    switch minutes {
    case ..<60: "\(minutes) minutos"
    case 60: "1 hora"
    case 1440: "1 dia"
    default: "\(minutes / 60) horas"
    }
}

func intervalShortLabel(_ minutes: Int) -> String {
    switch minutes {
    case ..<60: "\(minutes) min"
    case 1440: "1 dia"
    default: "\(minutes / 60) h"
    }
}

func intervalIcon(_ minutes: Int) -> String {
    switch minutes {
    case ..<15: "hare"
    case ..<30: "timer"
    case ..<60: "cup.and.saucer"
    case ..<120: "hourglass"
    case ..<360: "hourglass.bottomhalf.filled"
    case ..<720: "sun.max"
    case ..<1440: "moon.stars"
    default: "sunrise"
    }
}

struct LaunchAtLoginRow: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    private var subtitle: String {
        if let error { return error }
        if SMAppService.mainApp.status == .requiresApproval {
            return "Autorize em Ajustes do Sistema › Geral › Itens de Início."
        }
        return "O Pane abre sozinho quando você faz login."
    }

    var body: some View {
        SettingsRow(icon: "power", tint: .gray, title: "Abrir junto com o Mac", subtitle: subtitle) {
            Toggle("", isOn: Binding(get: { enabled }, set: update))
        }
    }

    private func update(_ value: Bool) {
        do {
            if value {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            error = nil
        } catch {
            self.error = "Não foi possível alterar: \(error.localizedDescription)"
        }
        enabled = SMAppService.mainApp.status == .enabled
    }
}
