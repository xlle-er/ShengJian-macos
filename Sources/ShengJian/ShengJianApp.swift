import SwiftUI
import ShengKit

@main
struct ShengJianApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle
    @StateObject private var navigation = WorkspaceNavigation()
    @StateObject private var overlay = OverlayController()
    @StateObject private var model: SessionModel
    init() {
        do {
            let store = try PrivateStore(product: .shengJian)
            _model = StateObject(wrappedValue: SessionModel(product: .shengJian, store: store))
        } catch {
            let app = NSApplication.shared; app.setActivationPolicy(.regular); app.activate(ignoringOtherApps: true)
            let alert = NSAlert(); alert.messageText = "无法打开声笺的私有数据目录"; alert.informativeText = "请检查磁盘空间与文件访问权限后重新打开。"; alert.runModal()
            exit(1)
        }
    }
    var body: some Scene {
        WindowGroup("声笺", id: "main") {
            SessionView(model: model, navigation: navigation, overlay: overlay).preferredColorScheme(model.colorScheme).environment(\.locale, model.locale).onAppear {
                lifecycle.model = model
                model.onCaptureStarted = { [weak session = model, weak captions = overlay] in
                    if let session { captions?.show(model: session) }
                }
            }
        }
        .defaultSize(width: 940, height: 650)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appSettings) {
                OpenWorkspaceButton(navigation: navigation, page: "services", title: model.localized("设置…"))
            }
            CommandMenu(model.localized("字幕")) {
                Button(model.localized("开启 / 暂停字幕")) { Task { if model.isCapturing { await model.stop(pause: true) } else { await model.start() } } }.keyboardShortcut("s", modifiers: [.command, .shift])
                Button(model.localized("切换字幕显示")) { model.cycleDisplayMode() }.keyboardShortcut("b", modifiers: [.command, .shift])
                Button(model.localized("停止字幕")) { Task { await model.stop() } }
            }
        }
        MenuBarExtra(model.localized("声笺"), systemImage: "captions.bubble") {
            Group {
            Text(LocalizedStringKey(model.statusTitle))
            Button(LocalizedStringKey(model.isCapturing ? "暂停" : "开启字幕")) { Task { if model.isCapturing { await model.stop(pause: true) } else { await model.start() } } }
            Button(LocalizedStringKey(overlay.visible ? "隐藏浮窗" : "显示浮窗")) { overlay.toggle(model: model) }
            Button(model.localized("停止字幕")) { Task { await model.stop() } }
            Divider()
            Menu("服务") {
                ForEach(model.profiles) { profile in Button(profile.name) { Task { await model.selectService(profile.id) } } }
            }.disabled(model.isBusy || model.isReconnecting)
            Menu("输入语言") {
                ForEach(model.languageOptions(source: true), id: \.0) { value in Button(value.1) { Task { await model.reconfigure(profileID: model.selectedProfile, source: value.0, target: model.targetLanguage) } } }
            }.disabled(model.isBusy || model.isReconnecting)
            Menu("翻译语言") {
                ForEach(model.languageOptions(source: false), id: \.0) { value in Button(value.1) { Task { await model.reconfigure(profileID: model.selectedProfile, source: model.sourceLanguage, target: value.0) } } }
            }.disabled(model.isBusy || model.isReconnecting)
            Menu("显示内容") {
                Button(model.localized("双语")) { model.displayMode = "bilingual"; model.savePreferences() }
                Button(model.localized("原文")) { model.displayMode = "original"; model.savePreferences() }
                Button(model.localized("译文")) { model.displayMode = "translation"; model.savePreferences() }
            }.disabled(model.isBusy || model.isReconnecting)
            Toggle("沉浸模式", isOn: $model.immersive).onChange(of: model.immersive) { _ in model.savePreferences() }
            Toggle("点击穿透", isOn: $model.clickThrough).onChange(of: model.clickThrough) { _ in model.savePreferences() }
            OpenWorkspaceButton(navigation: navigation, title: model.localized("显示主窗口"))
            Button(model.localized("退出声笺")) { NSApp.terminate(nil) }
            }.environment(\.locale, model.locale)
        }
    }
}

private struct OpenWorkspaceButton: View {
    @ObservedObject var navigation: WorkspaceNavigation
    var page: String? = nil
    let title: String
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button(LocalizedStringKey(title)) {
            if let page { navigation.page = page }
            if !navigation.revealMainWindow() { openWindow(id: "main") }
            NSApp.activate(ignoringOtherApps: true)
        }.keyboardShortcut(page == "services" ? KeyEquivalent(",") : KeyEquivalent("0"), modifiers: .command)
    }
}
