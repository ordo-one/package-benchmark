import Foundation
import PackagePlugin

@main
struct PluginFactory: BuildToolPlugin {
    func createBuildCommands(
        context: PackagePlugin.PluginContext, target: PackagePlugin.Target
    ) async throws
        -> [PackagePlugin.Command]
    {
        guard let target = target as? SwiftSourceModuleTarget else { return [] }
        guard target.kind == .executable else { return [] }
        let path = target.directoryURL.deletingLastPathComponent()
        guard path.lastPathComponent == "Benchmarks" else { return [] }

        let tool = try context.tool(named: "BenchmarkBoilerplateGenerator")
        let outputDirectory = context.pluginWorkDirectoryURL
        let swiftFile = outputDirectory.appending(path: "__BenchmarkBoilerplate.swift")
        let inputFiles = target.sourceFiles.filter { $0.url.pathExtension == "swift" }.map(\.url)
        let outputFiles: [URL] = [swiftFile]

        let commandArgs: [String] = [
            "--target", target.name,
            "--output", swiftFile.path(),
        ]

        let command: Command = .buildCommand(
            displayName: "Generating plugin support files",
            executable: tool.url,
            arguments: commandArgs,
            inputFiles: inputFiles,
            outputFiles: outputFiles
        )

        return [command]
    }
}
