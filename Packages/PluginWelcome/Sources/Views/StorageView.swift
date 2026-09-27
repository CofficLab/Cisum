import CisumUIComponents
import LumiUI
import SwiftUI

public struct StorageView: View {
    private let isICloudAvailable: Bool
    private let currentStorageSelection: WelcomeStorageSelection?
    private let updateStorageSelection: @MainActor (WelcomeStorageSelection) -> Void

    @State private var tempStorageSelection: WelcomeStorageSelection?

    public init(
        isICloudAvailable: Bool,
        currentStorageSelection: WelcomeStorageSelection?,
        updateStorageSelection: @escaping @MainActor (WelcomeStorageSelection) -> Void
    ) {
        self.isICloudAvailable = isICloudAvailable
        self.currentStorageSelection = currentStorageSelection
        self.updateStorageSelection = updateStorageSelection
        _tempStorageSelection = State(initialValue: WelcomeStorageSelectionPolicy.displayedSelection(
            currentStorageSelection: currentStorageSelection,
            isICloudAvailable: isICloudAvailable
        ))
    }

    public var body: some View {
        AppSettingSection(
            title: String(localized: "Media Storage Location", bundle: .module),
            titleAlignment: .center
        ) {
            VStack(spacing: 12) {
                AppSettingRow(
                    title: String(localized: "iCloud Drive", bundle: .module),
                    description: String(localized: "Files stored in iCloud\nAccessible on other devices\nEnsure sufficient iCloud storage", bundle: .module),
                    icon: .cisumIconCloud,
                    action: {
                        if isICloudAvailable {
                            updateSelection(.icloud)
                        }
                    }
                ) {
                    HStack {
                        if tempStorageSelection == .icloud {
                            Image(systemName: .cisumIconCheckmarkSimple)
                                .foregroundColor(.accentColor)
                        } else {
                            Text("Recommended", bundle: .module)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .opacity(isICloudAvailable ? 1 : 0.5)
                .disabled(!isICloudAvailable)

                if !isICloudAvailable {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .imageScale(.small)
                        Text("Sign in to iCloud in System Settings to use this option", bundle: .module)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 32)
                    .padding(.bottom, 8)
                }

                Divider()

                AppSettingRow(
                    title: String(localized: "App Local Storage", bundle: .module),
                    description: String(localized: "Stored within the app, data will be lost if app is deleted", bundle: .module),
                    icon: .cisumIconFolder,
                    action: {
                        updateSelection(.local)
                    }
                ) {
                    HStack {
                        if tempStorageSelection == .local {
                            Image(systemName: .cisumIconCheckmarkSimple)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
        }
    }

    private func onAppear() {
        let displayedSelection = WelcomeStorageSelectionPolicy.displayedSelection(
            currentStorageSelection: currentStorageSelection,
            isICloudAvailable: isICloudAvailable
        )
        tempStorageSelection = displayedSelection

        if let displayedSelection, WelcomeStorageSelectionPolicy.shouldPersistDisplayedSelectionOnAppear(
            currentStorageSelection: currentStorageSelection,
            displayedSelection: displayedSelection
        ) {
            updateSelection(displayedSelection)
        }
    }

    private func onDisappear() {
        guard let tempStorageSelection else { return }
        guard WelcomeStorageSelectionPolicy.shouldPersistDisplayedSelectionOnDisappear(
            currentStorageSelection: currentStorageSelection,
            displayedSelection: tempStorageSelection
        ) else { return }

        updateSelection(tempStorageSelection)
    }

    private func updateSelection(_ selection: WelcomeStorageSelection) {
        let validatedSelection = WelcomeStorageSelectionPolicy.validatedSelection(
            selection,
            isICloudAvailable: isICloudAvailable
        )
        tempStorageSelection = validatedSelection
        updateStorageSelection(validatedSelection)
    }
}

enum WelcomeStorageSelectionPolicy {
    static func validatedSelection(
        _ selection: WelcomeStorageSelection,
        isICloudAvailable: Bool
    ) -> WelcomeStorageSelection {
        if selection == .icloud && !isICloudAvailable {
            return .local
        }

        return selection
    }

    static func displayedSelection(
        currentStorageSelection: WelcomeStorageSelection?,
        isICloudAvailable: Bool
    ) -> WelcomeStorageSelection? {
        if let currentStorageSelection {
            if currentStorageSelection == .icloud && !isICloudAvailable {
                return .local
            }

            return currentStorageSelection
        }

        return isICloudAvailable ? .icloud : .local
    }

    static func defaultSelection(
        currentStorageSelection: WelcomeStorageSelection?,
        isICloudAvailable: Bool
    ) -> WelcomeStorageSelection {
        displayedSelection(
            currentStorageSelection: currentStorageSelection,
            isICloudAvailable: isICloudAvailable
        ) ?? (isICloudAvailable ? .icloud : .local)
    }

    static func shouldPersistDisplayedSelectionOnAppear(
        currentStorageSelection: WelcomeStorageSelection?,
        displayedSelection: WelcomeStorageSelection?
    ) -> Bool {
        currentStorageSelection != nil && displayedSelection != currentStorageSelection
    }

    static func shouldPersistDisplayedSelectionOnDisappear(
        currentStorageSelection: WelcomeStorageSelection?,
        displayedSelection: WelcomeStorageSelection?
    ) -> Bool {
        currentStorageSelection != nil && displayedSelection != currentStorageSelection
    }
}
