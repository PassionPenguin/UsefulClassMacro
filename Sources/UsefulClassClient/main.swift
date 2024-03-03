import Foundation
import UsefulClass

@UsefulClass(codingMembers: ["age: Int"],
             comparableMembers: ["age"],
             uselessInitializations: "status = 0")
class Recipe: Identifiable, Codable, Hashable, Equatable {
    var age: Int = 0
    
    private var status: Int = 1
    
}
