import CarthageKit
import Commandant
import Foundation
import Result
import ReactiveSwift

/// Type that encapsulates the configuration and evaluation of the `copy-frameworks` subcommand.
public struct CopyFrameworksCommand: CommandProtocol {
    public let verb = "copy-frameworks"
    public let function = "In a Run Script build phase, copies each framework specified by a SCRIPT_INPUT_FILE and/or SCRIPT_INPUT_FILE_LIST environment variables into the built app bundle"

    public func run(_ options: NoOptions<CarthageError>) -> Result<(), CarthageError> {

        let frameworksFolderURL: URL = frameworksFolder().value!
        let validArchitectureValues: [String] = validArchitectures().value!
        let codeSigningIdentityString: String = codeSigningIdentity().single()?.value! ?? "bla"
        let stripDebugSymbols: Bool = shouldStripDebugSymbols()
        let shouldCopyBCSymbolMap: Bool = buildActionIsArchiveOrInstall()
        let symbolsFolder: URL = appropriateDestinationFolder().value!

        return inputFiles()
            .flatMap(.merge) { frameworkPath -> SignalProducer<(), CarthageError> in
                return Xcode.copyFrameworks(frameworkPath: frameworkPath, frameworksFolder: frameworksFolderURL, symbolsFolder: symbolsFolder, validArchitectures: validArchitectureValues, codeSigningIdentity: codeSigningIdentityString, shouldStripDebugSymbols: stripDebugSymbols, shouldCopyBCSymbolMap: shouldCopyBCSymbolMap)
                    // Copy as many frameworks as possible in parallel.
                    .start(on: QueueScheduler(name: "org.carthage.CarthageKit.CopyFrameworks.copy"))
            }
            .waitOnCommand()
    }
}

private func codeSigningIdentity() -> SignalProducer<String?, CarthageError> {
    return SignalProducer(codeSigningAllowed)
        .attemptMap { codeSigningAllowed in
            guard codeSigningAllowed == true else { return .success(nil) }

            return getEnvironmentVariable("EXPANDED_CODE_SIGN_IDENTITY")
                .map { $0.isEmpty ? nil : $0 }
                .flatMapError {
                    // See https://github.com/Carthage/Carthage/issues/2472#issuecomment-395134166 regarding Xcode 10 betas
                    // … or potentially non-beta Xcode releases of major version 10 or later.

                    switch getEnvironmentVariable("XCODE_PRODUCT_BUILD_VERSION") {
                    case .success:
                        // See the above issue.
                        return .success(nil)
                    case .failure:
                        // For users calling `carthage copy-frameworks` outside of Xcode (admittedly,
                        // a small fraction), this error is worthwhile in being a signpost in what’s
                        // necessary to add to achieve (for what most is the goal) of ensuring
                        // that code signing happens.
                        return .failure($0)
                    }
            }
    }
}

private func codeSigningAllowed() -> Bool {
    return getEnvironmentVariable("CODE_SIGNING_ALLOWED")
        .map { $0 == "YES" }.value ?? false
}

private func shouldStripDebugSymbols() -> Bool {
    return getEnvironmentVariable("COPY_PHASE_STRIP")
        .map { $0 == "YES" }.value ?? false
}

// The fix for https://github.com/Carthage/Carthage/issues/1259
private func appropriateDestinationFolder() -> Result<URL, CarthageError> {
    if buildActionIsArchiveOrInstall() {
        return builtProductsFolder()
    } else {
        return targetBuildFolder()
    }
}

private func builtProductsFolder() -> Result<URL, CarthageError> {
    return getEnvironmentVariable("BUILT_PRODUCTS_DIR")
        .map { URL(fileURLWithPath: $0, isDirectory: true) }
}

private func targetBuildFolder() -> Result<URL, CarthageError> {
    return getEnvironmentVariable("TARGET_BUILD_DIR")
        .map { URL(fileURLWithPath: $0, isDirectory: true) }
}

private func frameworksFolder() -> Result<URL, CarthageError> {
    return appropriateDestinationFolder()
        .flatMap { url -> Result<URL, CarthageError> in
            getEnvironmentVariable("FRAMEWORKS_FOLDER_PATH")
                .map { url.appendingPathComponent($0, isDirectory: true) }
    }
}

private func validArchitectures() -> Result<[String], CarthageError> {
    return getEnvironmentVariable("VALID_ARCHS").map { architectures -> [String] in
        return architectures.components(separatedBy: " ")
    }
}

private func buildActionIsArchiveOrInstall() -> Bool {
    // archives use ACTION=install
    return getEnvironmentVariable("ACTION").value == "install"
}

private func inputFiles() -> SignalProducer<String, CarthageError> {
    return SignalProducer(values: scriptInputFiles(), scriptInputFileLists())
        .flatten(.merge)
        .uniqueValues()
}

private func scriptInputFiles() -> SignalProducer<String, CarthageError> {
    switch getEnvironmentVariable("SCRIPT_INPUT_FILE_COUNT") {
    case .success(let count):
        if let count = Int(count) {
            return SignalProducer<Int, CarthageError>(0..<count).attemptMap { getEnvironmentVariable("SCRIPT_INPUT_FILE_\($0)") }
        } else {
            return SignalProducer(error: .invalidArgument(description: "SCRIPT_INPUT_FILE_COUNT did not specify a number"))
        }
    case .failure:
        return .empty
    }
}

private func scriptInputFileLists() -> SignalProducer<String, CarthageError> {
    switch getEnvironmentVariable("SCRIPT_INPUT_FILE_LIST_COUNT") {
    case .success(let count):
        if let count = Int(count) {
            return SignalProducer<Int, CarthageError>(0..<count)
                .attemptMap { getEnvironmentVariable("SCRIPT_INPUT_FILE_LIST_\($0)") }
                .flatMap(.merge) { fileList -> SignalProducer<String, CarthageError> in
                    let fileListURL = URL(fileURLWithPath: fileList, isDirectory: true)
                    return SignalProducer<String, NSError>(result: Result(catching: { try String(contentsOfFile: fileList) }))
                        .mapError { CarthageError.readFailed(fileListURL, $0) }
                }
                .map { $0.split(separator: "\n").map(String.init) }
                .flatMap(.merge) { SignalProducer($0) }
        } else {
            return SignalProducer(error: .invalidArgument(description: "SCRIPT_INPUT_FILE_LIST_COUNT did not specify a number"))
        }
    case .failure:
        return .empty
    }
}
