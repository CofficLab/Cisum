import ProviderTheme
import ProviderStorage
import CisumKernelSupport
import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Cisum 应用命令装配（对齐 Lumi `FactoryLumi/AppCommands.swift`）。
///
/// 菜单栏命令的装配集中在 Factory 包内完成；宿主 App 只需
/// `.commands { FactoryCisum.makeCommands() }`，不需要关心命令从哪来。
public struct CisumAppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    public init() {
        #if os(macOS)
        Task { @MainActor in
            CisumMenuInstaller.shared.start()
        }
        #endif
    }

    public var body: some Commands {
        // 菜单栏「设置…」入口（⌘,）——对齐 Lumi 的设置窗口入口。
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: AppBootstrap.settingsWindowID)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

#if os(macOS)

/// Installs Cisum's dynamic top-level menus into the AppKit menu bar.
///
/// SwiftUI creates and can replace its `NSMenu` tree after the command scene
/// is evaluated. The installer therefore waits for the main kernel and keeps
/// the menu items synchronized with the current theme service. This mirrors
/// Lumi's runtime menu bridge while keeping the Cisum command surface local
/// to its Factory package.
@MainActor
private final class CisumMenuInstaller {
    static let shared = CisumMenuInstaller()

    private var pollingTask: Task<Void, Never>?
    private weak var installedMainMenu: NSMenu?
    private var installedMenus: [String: NSMenuItem] = [:]
    private var installedItems: [String: NSMenuItem] = [:]
    private var actionTargets: [String: CisumMenuActionTarget] = [:]
    private var lastStructureSignature: String?

    private let debugMenuID = "com.coffic.cisum.menu.debug"
    private let themeMenuID = "com.coffic.cisum.menu.theme"

    func start() {
        guard pollingTask == nil else { return }

        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.synchronizeIfPossible()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func synchronizeIfPossible() {
        guard let mainMenu = NSApplication.shared.mainMenu,
              let kernel = FactoryCisum.mainKernel else { return }

        if installedMainMenu !== mainMenu {
            installedMainMenu = mainMenu
            lastStructureSignature = nil
        }

        let groups = makeGroups(kernel: kernel)
        let structureSignature = groups.map { group in
            "\(group.id)=\(group.name)=[\(group.items.map { "\($0.id)=\($0.title)" }.joined(separator: ";"))]"
        }.joined(separator: "|")
        let wasEvicted = installedMenus.values.contains { installed in
            !mainMenu.items.contains { $0 === installed }
        }

        if structureSignature != lastStructureSignature || wasEvicted {
            synchronize(in: mainMenu, groups: groups)
            lastStructureSignature = structureSignature
        } else {
            updateStates(for: groups)
        }
    }

    private func makeGroups(kernel: KernelCoreContainer) -> [CisumMenuGroup] {
        [
            CisumMenuGroup(
                id: debugMenuID,
                name: menuString("DEBUG"),
                items: makeDebugItems(kernel: kernel)
            ),
            CisumMenuGroup(
                id: themeMenuID,
                name: menuString("Theme"),
                items: makeThemeItems(kernel: kernel)
            ),
        ]
    }

    private func makeDebugItems(kernel: KernelCoreContainer) -> [CisumMenuItem] {
        [
            CisumMenuItem(id: "debug.openAppSupport", title: menuString("Open App Support Directory")) {
                self.openDirectory(
                    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
                    missingMessage: self.menuString("App Support directory does not exist")
                )
            },
            CisumMenuItem(id: "debug.openContainer", title: menuString("Open Container Directory")) {
                let url = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier ?? ""
                )
                self.openDirectory(url, missingMessage: self.menuString("Container directory does not exist"))
            },
            CisumMenuItem(id: "debug.openDocuments", title: menuString("Open Documents Directory")) {
                self.openDirectory(
                    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                    missingMessage: self.menuString("Documents directory does not exist")
                )
            },
            CisumMenuItem(id: "debug.openDatabase", title: menuString("Open Database Directory")) {
                self.openDirectory(
                    kernel.resolveProvider((any StorageProviding).self)?.databaseRoot,
                    missingMessage: self.menuString("Database directory does not exist")
                )
            },
        ]
    }

    private func makeThemeItems(kernel: KernelCoreContainer) -> [CisumMenuItem] {
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else { return [] }
        return theme.allThemeContributions.map { contribution in
            CisumMenuItem(
                id: "\(themeMenuID).select.\(contribution.id)",
                title: contribution.displayName,
                state: theme.selectedThemeID == contribution.id
            ) {
                theme.selectTheme(contribution.id)
            }
        }
    }

    private func synchronize(in mainMenu: NSMenu, groups: [CisumMenuGroup]) {
        let groupIDs = Set(groups.map(\.id))
        let removedGroups = installedMenus.filter { !groupIDs.contains($0.key) }
        for (groupID, menuItem) in removedGroups {
            if mainMenu.items.contains(where: { $0 === menuItem }) {
                mainMenu.removeItem(menuItem)
            }
            installedMenus.removeValue(forKey: groupID)
            removeInstalledItems(for: groupID)
        }

        for group in groups {
            let rootItem = installedMenus[group.id]
                ?? NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
            rootItem.title = group.name
            let submenu = rootItem.submenu ?? NSMenu(title: group.name)
            submenu.title = group.name
            removeInstalledItems(for: group.id)
            submenu.removeAllItems()

            for item in group.items {
                let target = CisumMenuActionTarget(action: item.action)
                let child = NSMenuItem(
                    title: item.title,
                    action: #selector(CisumMenuActionTarget.performAction(_:)),
                    keyEquivalent: ""
                )
                child.state = item.state ? .on : .off
                child.target = target
                submenu.addItem(child)
                let itemKey = installedItemKey(groupID: group.id, itemID: item.id)
                installedItems[itemKey] = child
                actionTargets[itemKey] = target
            }

            rootItem.submenu = submenu
            if !mainMenu.items.contains(where: { $0 === rootItem }) {
                mainMenu.addItem(rootItem)
            }
            installedMenus[group.id] = rootItem
        }

        updateStates(for: groups)
    }

    private func updateStates(for groups: [CisumMenuGroup]) {
        for group in groups {
            for item in group.items {
                let key = installedItemKey(groupID: group.id, itemID: item.id)
                installedItems[key]?.state = item.state ? .on : .off
            }
        }
    }

    private func removeInstalledItems(for groupID: String) {
        let prefix = "\(groupID)."
        installedItems.keys.filter { $0.hasPrefix(prefix) }.forEach { installedItems.removeValue(forKey: $0) }
        actionTargets.keys.filter { $0.hasPrefix(prefix) }.forEach { actionTargets.removeValue(forKey: $0) }
    }

    private func installedItemKey(groupID: String, itemID: String) -> String {
        "\(groupID).\(itemID)"
    }

    private func openDirectory(_ url: URL?, missingMessage: String) {
        guard let url else {
            let alert = NSAlert()
            alert.messageText = menuString("Error Opening Directory")
            alert.informativeText = missingMessage
            alert.alertStyle = .warning
            alert.addButton(withTitle: menuString("OK"))
            alert.runModal()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func menuString(_ key: String) -> String {
        String(localized: .init(key), bundle: .module)
    }
}

@MainActor
private struct CisumMenuGroup {
    let id: String
    let name: String
    let items: [CisumMenuItem]
}

@MainActor
private struct CisumMenuItem {
    let id: String
    let title: String
    let state: Bool
    let action: @MainActor @Sendable () -> Void

    init(
        id: String,
        title: String,
        state: Bool = false,
        action: @escaping @MainActor @Sendable () -> Void
    ) {
        self.id = id
        self.title = title
        self.state = state
        self.action = action
    }
}

@MainActor
private final class CisumMenuActionTarget: NSObject {
    private let action: @MainActor @Sendable () -> Void

    init(action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    @objc func performAction(_ sender: NSMenuItem) {
        action()
    }
}

#endif