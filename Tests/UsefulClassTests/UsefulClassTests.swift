import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

import UsefulClassMacros

let testMacros: [String: Macro.Type] = [
    "UsefulClass": UsefulClassMacro.self,
]

final class UsefulClassTests: XCTestCase {
    func testUsefulClass() {
        assertMacroExpansion(
            """
             @UsefulClass(codingMembers: ["age: Int"],
                          comparableMembers: ["age"],
                          uselessInitializations: "status = 0")
             class Recipe: Identifiable, Codable, Hashable, Equatable {
                 var age: Int = 0
                 
                 private var status: Int = 1
                 
             }
            """,
            expandedSource: """
            class Recipe: Identifiable, Codable, Hashable, Equatable {
                var age: Int = 0
                
                private var status: Int = 1

                var id: String {
                    publicId
                }

                var publicId: String

                var name: String

                var createdAt: Date

                var updatedAt: Date

                var deletedAt: Date?

                static func propertiesEqual(lhs: Recipe, rhs: Recipe) -> Bool {
                    return lhs.age == rhs.age && lhs.name == rhs.name
                }

                static func == (lhs: Recipe, rhs: Recipe) -> Bool {
                    return lhs.age == rhs.age && lhs.id == rhs.id && lhs.publicId == rhs.publicId && lhs.name == rhs.name && lhs.createdAt == rhs.createdAt && lhs.updatedAt == rhs.updatedAt && lhs.deletedAt == rhs.deletedAt
                }

                func hash(into hasher: inout Hasher) {
                    hasher.combine(age)
                    hasher.combine(id)
                    hasher.combine(publicId)
                    hasher.combine(name)
                    hasher.combine(createdAt)
                    hasher.combine(updatedAt)
                    hasher.combine(deletedAt)
                }

                private enum CodingKeys: String, CodingKey {
                    case age
                    case id
                    case publicId
                    case name
                    case createdAt
                    case updatedAt
                    case deletedAt
                }

                required init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    age = try container.decode(Int.self, forKey: .age)

                    publicId = try container.decode(String.self, forKey: .publicId)
                    name = try container.decode(String.self, forKey: .name)
                    createdAt = try container.decode(Date.self, forKey: .createdAt)
                    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
                    deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
                    status = 0
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(age, forKey: .age)
                    try container.encode(id, forKey: .id)
                    try container.encode(publicId, forKey: .publicId)
                    try container.encode(name, forKey: .name)
                    try container.encode(createdAt, forKey: .createdAt)
                    try container.encode(updatedAt, forKey: .updatedAt)
                    try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
                }

                init() {
                    age = 0

                    publicId = ""
                    name = ""
                    createdAt = Date()
                    updatedAt = Date()
                    deletedAt = nil
                    status = 0
                }
            
             }
            """,
            macros: testMacros
        )
    }
}
