import Foundation
import Regex
import SwiftCLI
import SwiftShell
import Yams

enum GenerateCommandError: ProcessError {
    var exitStatus: Int32 {
        -1
    }
    
    case notFoundConfig(path: String)
    case invalidConfig
    case invalidEnvironmentVariable(variableName: String)
    
    var message: String? {
        switch self {
        case let .notFoundConfig(path):
            return "Error! Could not find \(path) \nCreate a configuration file (sskeys.yml) or set your custom path (--config)..."
        case .invalidConfig:
            return "Error! File cannot be generated (Verify the environments variables and the output path)..."
        case let .invalidEnvironmentVariable(variableName):
            return "Error! The environment variable '\(variableName)' was not found..."
        }
    }
}

class GenerateCommand: Command {
    let name = "generate"
    var shortDescription: String = "Generate a .swift file with secrets"
    
    @Key("-c", "--config", description: "Configuration file path")
    var config: String?

    @Key("-o", "--output", description: "Output file path")
    var output: String?
    
    @Key("-f", "--factor", description: "Custom cipher factor")
    var factor: Int?
    
    func execute() throws {
        let config: String
        
        if let givenConfig = self.config {
            config = givenConfig
        } else {
            config = "sskeys.yml"
        }
        let path: String
        if (config as NSString).isAbsolutePath {
          path = config
        } else {
          path = main.currentdirectory + "/" + config
        }
        let contents: String
        do {
            contents = try String(contentsOfFile: path)
        } catch {
            throw GenerateCommandError.notFoundConfig(path: path)
        }
        
        let secrets = try Yams.load(yaml: contents) as? [String: Any]
        let keys = try readKeys(from: secrets)
        let generator = Generator(values: keys,
                                  outputPath: output ?? "",
                                  customFactor: factor ?? 32)
        try generator.generate()
    }
    
    func readKeys(from secrets: [String: Any]?) throws -> [String: String] {
        guard let keys = secrets?["keys"] as? [String: String] else {
            return [:]
        }
        
        var auxKeys = [String: String]()
        for (key, value) in keys {
            auxKeys[key] = try convertToRealValue(value)
        }
        
        return auxKeys
    }
    
    func convertToRealValue(_ value: String) throws -> String {
        if isEnvironment(value) {
            let filteredValue = value.replacingFirst(matching: "(\\$\\{)(\\w{1,})(\\})", with: "$2")
            guard let environmentValue = ProcessInfo.processInfo.environment[filteredValue] else {
                throw GenerateCommandError
                    .invalidEnvironmentVariable(variableName: filteredValue)
            }
            return environmentValue
        } else {
            return value
        }
    }
    
    func isEnvironment(_ value: String) -> Bool {
        return Regex("\\$\\{(\\w{1,})\\}").matches(value)
    }
}
