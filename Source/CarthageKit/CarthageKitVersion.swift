/// Defines the current CarthageKit version.
public struct CarthageKitVersion {
    public let value: SemanticVersion
    public static let current = CarthageKitVersion(value: SemanticVersion(0, 40, 0, prereleaseIdentifiers: [], buildMetadataIdentifiers: ["nsoperations"]))
}
