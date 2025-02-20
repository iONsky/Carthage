import XCDBLD

/// The build options used for building `xcodebuild` command.
public struct BuildOptions {
    /// The Xcode configuration to build.
    public var configuration: String
    /// The platforms to build for.
    public var platforms: Set<Platform>
    /// The toolchain to build with.
    public var toolchain: String?
    /// The path to the custom derived data folder.
    public var derivedDataPath: String?
    /// Whether to skip building if valid cached builds exist.
    public var cacheBuilds: Bool
    /// Whether to use downloaded binaries if possible.
    public var useBinaries: Bool
    /// Custom executable or shell script to perform the caching implementation: recieves five arguments: dependencyName, dependencyVersion, buildConfiguration, swiftVersion, targetFilePath
    public var customCacheCommand: String?
    /// Whether to track and compare local changes made to the dependency's source code (will cause a rebuild if so)
    public var trackLocalChanges: Bool
    /// Whether to take ~/.netrc into account for credentials when downloading binaries
    public var useNetrc: Bool

    public init(
        configuration: String,
        platforms: Set<Platform> = [],
        toolchain: String? = nil,
        derivedDataPath: String? = nil,
        cacheBuilds: Bool = true,
        useBinaries: Bool = true,
        customCacheCommand: String? = nil,
        trackLocalChanges: Bool = false,
        useNetrc: Bool = false
        ) {
        self.configuration = configuration
        self.platforms = platforms
        self.toolchain = toolchain
        self.derivedDataPath = derivedDataPath
        self.cacheBuilds = cacheBuilds
        self.useBinaries = useBinaries
        self.customCacheCommand = customCacheCommand
        self.trackLocalChanges = trackLocalChanges
        self.useNetrc = useNetrc
    }
}
