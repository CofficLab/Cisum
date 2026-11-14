public enum WelcomePluginHost {
    public typealias HasStorageLocation = @MainActor @Sendable () -> Bool
    public typealias IsICloudAvailable = @MainActor @Sendable () -> Bool
    public typealias CurrentStorageSelection = @MainActor @Sendable () -> WelcomeStorageSelection?
    public typealias UpdateStorageSelection = @MainActor @Sendable (WelcomeStorageSelection) -> Void

    private nonisolated(unsafe) static var hasStorageLocationHandler: HasStorageLocation = { false }
    private nonisolated(unsafe) static var isICloudAvailableHandler: IsICloudAvailable = { false }
    private nonisolated(unsafe) static var currentStorageSelectionHandler: CurrentStorageSelection = { nil }
    private nonisolated(unsafe) static var updateStorageSelectionHandler: UpdateStorageSelection = { _ in }

    public static func configure(
        hasStorageLocation: @escaping HasStorageLocation,
        isICloudAvailable: @escaping IsICloudAvailable,
        currentStorageSelection: @escaping CurrentStorageSelection,
        updateStorageSelection: @escaping UpdateStorageSelection
    ) {
        hasStorageLocationHandler = hasStorageLocation
        isICloudAvailableHandler = isICloudAvailable
        currentStorageSelectionHandler = currentStorageSelection
        updateStorageSelectionHandler = updateStorageSelection
    }

    @MainActor
    static var hasStorageLocation: Bool {
        hasStorageLocationHandler()
    }

    @MainActor
    static var isICloudAvailable: Bool {
        isICloudAvailableHandler()
    }

    @MainActor
    static var currentStorageSelection: WelcomeStorageSelection? {
        currentStorageSelectionHandler()
    }

    @MainActor
    static func updateStorageSelection(_ selection: WelcomeStorageSelection) {
        updateStorageSelectionHandler(selection)
    }
}
