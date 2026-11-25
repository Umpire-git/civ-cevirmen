import SwiftUI
import ReplayKit
import Translation

@main
struct CivCevirmenApp: App {
    @StateObject private var engine = Engine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Civ Çevirmen").font(.largeTitle.bold())

                PiPHostView(pip: engine.pip)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .frame(maxWidth: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(engine.status)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Toggle("Okuma paneli (büyük Türkçe metin)", isOn: $engine.panelMode)
                    .frame(maxWidth: 520)
                Toggle("Görüntü ters görünüyorsa çevir (180°)", isOn: $engine.rotate180)
                    .frame(maxWidth: 520)

                VStack(alignment: .leading, spacing: 14) {
                    step("1", "Dil paketini hazırla (ilk seferde indirme ister).") {
                        Button("Dilleri hazırla") { engine.prepareLanguages() }
                            .buttonStyle(.bordered)
                    }
                    step("2", "Yüzen pencereyi aç.") {
                        Button("Yüzen pencereyi aç") { engine.pip.start() }
                            .buttonStyle(.borderedProminent)
                    }
                    step("3", "Bu düğmeye bas → \"Civ Çevirmen\" seç → Yayını Başlat.") {
                        BroadcastPicker()
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color.red.opacity(0.15)))
                    }
                    step("4", "Civ 7'yi aç. Yüzen pencerede Türkçe hali görünür; büyütüp kenara çekebilirsin.") {
                        EmptyView()
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
            }
            .padding()
        }
        .translationTask(engine.translationConfig) { session in
            await engine.translator.run(session: session) { ready in
                Task { @MainActor in engine.languagesReady(ready) }
            }
        }
    }

    @ViewBuilder
    private func step<V: View>(_ n: String, _ text: String, @ViewBuilder _ content: () -> V) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(n).font(.headline).frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                content()
            }
        }
    }
}

/// Sistem "Yayını Başlat" düğmesi.
struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let v = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 56, height: 56))
        v.showsMicrophoneButton = false
        v.preferredExtension = BroadcastPicker.extensionID
        return v
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}

    /// SideStore paket kimliğini değiştirebildiği için eklenti kimliğini uygulamanın içinden okuyoruz.
    static var extensionID: String? {
        guard let url = Bundle.main.builtInPlugInsURL,
              let items = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        else { return nil }
        return items.first { $0.pathExtension == "appex" }.flatMap { Bundle(url: $0)?.bundleIdentifier }
    }
}
