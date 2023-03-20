import PackagePlugin

@main
struct PluginFactory: BuildToolPlugin {
    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        guard let target = target as? SwiftSourceModuleTarget else { return [] }
        guard target.kind == .executable else { return [] }
        let path = target.directory.removingLastComponent()
        guard path.lastComponent == "Benchmarks" else { return [] }

        let tool = try context.tool(named: "BenchmarkBoilerplateGenerator")
        let outputDirectory = context.pluginWorkDirectory
        let swiftFile = outputDirectory.appending("__BenchmarkBoilerplate.swift")
        let inputFiles = target.sourceFiles.filter { $0.path.extension == "swift" }.map(\.path)
        let outputFiles: [Path] = [swiftFile]

        let commandArgs: [String] = [
            "--target", target.name,
            "--output", swiftFile.string
        ]

        let command: Command = .buildCommand(
            displayName: "Generating plugin support files",
            executable: tool.path,
            arguments: commandArgs,
            inputFiles: inputFiles,
            outputFiles: outputFiles
        )

        return [command]
    }
}
