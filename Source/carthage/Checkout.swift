import CarthageKit
import Commandant
import Foundation
import Result
import ReactiveSwift
import Curry

/// Type that encapsulates the configuration and evaluation of the `checkout` subcommand.
public struct CheckoutCommand: CommandProtocol {
    public struct Options: OptionsProtocol {
        public let useSSH: Bool
        public let useSubmodules: Bool
        public let lockTimeout: Int?
        public let colorOptions: ColorOptions
        public let directoryPath: String
        public let dependenciesToCheckout: [String]?

        private init(useSSH: Bool,
                     useSubmodules: Bool,
                     lockTimeout: Int?,
                     colorOptions: ColorOptions,
                     directoryPath: String,
                     dependenciesToCheckout: [String]?
            ) {
            self.useSSH = useSSH
            self.useSubmodules = useSubmodules
            self.lockTimeout = lockTimeout
            self.colorOptions = colorOptions
            self.directoryPath = directoryPath
            self.dependenciesToCheckout = dependenciesToCheckout
        }

        public static func evaluate(_ mode: CommandMode) -> Result<Options, CommandantError<CarthageError>> {
            return evaluate(mode, dependenciesUsage: "the dependency names to checkout")
        }

        public static func evaluate(_ mode: CommandMode, dependenciesUsage: String) -> Result<Options, CommandantError<CarthageError>> {
            return curry(self.init)
                <*> mode <| Option(key: "use-ssh", defaultValue: false, usage: "use SSH for downloading GitHub repositories")
                <*> mode <| Option(key: "use-submodules", defaultValue: false, usage: "add dependencies as Git submodules")
                <*> mode <| Option<Int?>(key: "lock-timeout", defaultValue: nil, usage: "timeout in seconds to wait for an exclusive lock on shared files, defaults to no timeout")
                <*> ColorOptions.evaluate(mode)
                <*> mode <| Option(key: "project-directory", defaultValue: FileManager.default.currentDirectoryPath, usage: "the directory containing the Carthage project")
                <*> (mode <| Argument(defaultValue: [], usage: dependenciesUsage, usageParameter: "dependency names")).map { $0.isEmpty ? nil : $0 }
        }

        /// Attempts to load the project referenced by the options, and configure it
        /// accordingly.
        public func loadProject(useNetrc: Bool) -> SignalProducer<Project, CarthageError> {
            let directoryURL = URL(fileURLWithPath: self.directoryPath, isDirectory: true)
            let project = Project(directoryURL: directoryURL, useNetrc: useNetrc)
            project.preferHTTPS = !self.useSSH
            project.useSubmodules = self.useSubmodules
            project.lockTimeout = self.lockTimeout

            let eventSink = ProjectEventLogger(colorOptions: colorOptions)
            project.projectEvents.observeValues { eventSink.log(event: $0) }

            return SignalProducer(value: project)
        }
    }

    public let verb = "checkout"
    public let function = "Check out the project's dependencies"

    public func run(_ options: Options) -> Result<(), CarthageError> {
        return self.checkoutWithOptions(options, useNetrc: false)
            .waitOnCommand()
    }

    /// Checks out dependencies with the given options.
    public func checkoutWithOptions(_ options: Options, useNetrc: Bool) -> SignalProducer<(), CarthageError> {
        return options.loadProject(useNetrc: useNetrc)
            .flatMap(.merge) { $0.checkoutResolvedDependencies(options.dependenciesToCheckout, buildOptions: nil) }
    }
}
