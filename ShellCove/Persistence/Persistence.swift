import Foundation
import SwiftData

/// 数据库容器的统一入口。测试通过 inMemory 参数使用内存库。
enum Persistence {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            "ShellCove",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: ShellCoveMigrationPlan.self,
            configurations: configuration
        )
    }
}
