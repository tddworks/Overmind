import Foundation

/// Finds service definitions. Built-ins ship in this module's bundle; no Swift lists one.
public enum ServiceCatalog {
    public static func builtIn(_ id: String) throws(DefinitionError) -> ServiceDefinition {
        guard let url = Bundle.module.url(forResource: id, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { throw .notFound(id) }
        return try ServiceDefinition(json: data)
    }

    /// Every built-in, in tab order.
    public static func builtIns() throws(DefinitionError) -> [ServiceDefinition] {
        var services: [ServiceDefinition] = []
        for url in Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [] {
            guard let data = try? Data(contentsOf: url) else { throw .notFound(url.lastPathComponent) }
            services.append(try ServiceDefinition(json: data))
        }
        return services.sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }
}
