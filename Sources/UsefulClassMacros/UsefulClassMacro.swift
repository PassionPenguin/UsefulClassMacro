import SwiftCompilerPlugin
import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `UsefulClass` macro, designed to enhance a class by providing members declarations.
///
/// The macro takes arrays `codingMembers`, `comparableMembers` of literal `String` values, `uselessInitializations` of literal `String` value, and expands the class by generating members.
public struct UsefulClassMacro {
    private let className: String
    private var comparableMembers: [String] = []
    private var codingMembers: [(name: String, type: String, nullable: Bool, getOnly: Bool)] = []
    private var uselessInitializations = ""
    
    // Run once to takes in AST first
    init(node: AttributeSyntax, declaration: some DeclGroupSyntax, context: some MacroExpansionContext) throws {
        // Check if UsefulClassMacro is attached to a class
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw NSError(domain: "UsefulClassMacro should only be attached to a class", code: 0)
        }
        
        // Make sure arguments count and type are correctly correspondingly
        guard
            case .argumentList(let arguments) = node.arguments,
            arguments.count == 3
        else {
            throw NSError(domain: "UsefulClassMacro requires 2 array arguments", code: 0)
        }
        
        // Save the class name the macro attached to
        className = classDecl.name.text
        
        // Parse the arguments by iterating through `arguments`
        for arg in arguments {
            // Each argument is a LabeledExpr, consisting of label and expression
            guard let labeledExpr = arg.as(LabeledExprSyntax.self),
                  let labelText = labeledExpr.label?.text else {
                throw NSError(domain: "UsefulClassMacro requires array arugment `comparableMembers`", code: 0)
            }
            
            // Compare the label text with the arguments we need to have, and save the arguments into class variables for further using
            switch labelText{
            case "comparableMembers":
                comparableMembers = try decodeArrayExpr(labeledExpr) + ["name"]
                break
            case "codingMembers":
                codingMembers = try decodeArrayExpr(labeledExpr).map { member in
                    let components = member.components(separatedBy: ": ")
                    let nullable = components[1].last == "?"
                    return (components[0], String(components[1].dropLast(nullable ? 1 : 0)), nullable, false)
                } + [("id", "String", false, true),("publicId", "String", false, false),("name", "String", false, false),("createdAt", "Date", false, false),("updatedAt", "Date", false, false),("deletedAt", "Date", true, false)]
            case "uselessInitializations":
                uselessInitializations = (labeledExpr.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text)!
            default:
                throw NSError(domain: "UsefulClassMacro found unknown argument named \(labelText)", code: 0)
            }
        }
    }
    
    /// This function will generate func member named `propertiesEqual`
    func makePropertiesEqualFunction() -> DeclSyntax {
        let comparableStrings = comparableMembers.map { member in
            "lhs.\(member) == rhs.\(member)"
        }
        
        return """
        static func propertiesEqual(lhs: \(raw: className), rhs: \(raw: className)) -> Bool {
        return \(raw: comparableStrings.joined(separator: "&&"))
        }
        """
    }
    
    /// This function will generate func member named `==`
    func makeEquatableFunction() -> DeclSyntax {
        let codingStrings = codingMembers.map { member in
            "lhs.\(member.name) == rhs.\(member.name)"
        }
        
        return """
        static func ==(lhs: \(raw: className), rhs: \(raw: className)) -> Bool {
        return \(raw: codingStrings.joined(separator: "&&"))
        }
        """
    }
    
    /// This function will generate func member named `hash`
    func makeHashableFunction() -> DeclSyntax {
        let hashingStrings = codingMembers.map { member in
            "hasher.combine(\(member.name))"
        }
        
        return """
        func hash(into hasher: inout Hasher) {
        \(raw: hashingStrings.joined(separator: "\n"))
        }
        """
    }
    
    /// This function will generate enum member named `CodingKeys`
    func makeCodingKeys() -> DeclSyntax {
        let codingKeyStrings = codingMembers.map { member in
            "case \(member.name)"
        }
        
        return """
        private enum CodingKeys: String, CodingKey {
        \(raw: codingKeyStrings.joined(separator: "\n"))
        }
        """
    }
    
    /// This function will generate func member named `init`, which will
    /// be a initialization function to create a class with all member value
    /// initialized by decoding value from `decoder: Decoder` argument
    func makeDecodeInitFunction() -> DeclSyntax {
        let initStrings = codingMembers.map { member in
            if !member.getOnly {
                if member.nullable {
                    "\(member.name) = try container.decodeIfPresent(\(member.type).self, forKey: .\(member.name))"
                } else {
                    "\(member.name) = try container.decode(\(member.type).self, forKey: .\(member.name))"
                }
            } else {
                ""
            }
        }
        
        return """
        required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        \(raw: initStrings.joined(separator: "\n"))
        \(raw: uselessInitializations)
        }
        """
    }
    
    /// This function will generate func member named `encode`
    func makeEncodeFunction() -> DeclSyntax {
        let encodeStrings = codingMembers.map { member in
            if member.nullable {
                "try container.encodeIfPresent(\(member.name), forKey: .\(member.name))"
            } else {
                "try container.encode(\(member.name), forKey: .\(member.name))"
            }
        }
        
        return """
        func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        \(raw: encodeStrings.joined(separator: "\n"))
        }
        """
    }
    
    /// This function will generate func member named `init`, which will
    /// be a initialization function to create a class with all member value
    /// set to empty (e.g. empty string, 0, nil)
    func makeEmptyClass() -> DeclSyntax {
        let initStrings = codingMembers.map { member in
            if !member.getOnly {
                if member.nullable {
                    return "\(member.name) = nil"
                } else {
                    var defaultValue = ""
                    switch member.type {
                    case "String":
                        defaultValue = "\"\""
                    case "Int":
                        defaultValue = "0"
                    case "Double":
                        defaultValue = "0.0"
                    default:
                        defaultValue = "\(member.type)()"
                    }
                    
                    return "\(member.name) = \(defaultValue)"
                }
            } else {
                return ""
            }
        }
        
        return """
        init() {
        \(raw: initStrings.joined(separator: "\n"))
        \(raw: uselessInitializations)
        }
        """
    }
    
    /// This function will generate func member named `init`, which will
    /// be a initialization function to create a class with all members set by
    /// values get from function arguments
    func makeInit() -> DeclSyntax {
        let argStrings = codingMembers.map { member in
            if !member.getOnly {
                if member.nullable {
                    return "\(member.name): \(member.type)\(member.nullable ? "?" : "") = nil"
                } else {
                    return "\(member.name): \(member.type)"
                }
            } else {
                return ""
            }
        }
        let initStrings = codingMembers.map { member in
            if !member.getOnly {
                return "self.\(member.name) = \(member.name)"
            } else {
                return ""
            }
        }
        
        return """
        init(
            \(raw: argStrings.joined(separator: "\n"))
        ) {
        \(raw: initStrings.joined(separator: "\n"))
        \(raw: uselessInitializations)
        }
        """
    }
    
    /// This function will generate required membets
    func makeRequiredMembers() -> [DeclSyntax] {
        return [
            "var id: String {publicId}",
            "var publicId: String",
            "var name: String",
            "var createdAt: Date",
            "var updatedAt: Date",
            "var deletedAt: Date?"
        ]
    }
}

extension UsefulClassMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext) throws -> [DeclSyntax] {
            let macro = try UsefulClassMacro(node: node, declaration: declaration, context: context)
            
            return macro.makeRequiredMembers() +
            [
                macro.makePropertiesEqualFunction(),
                macro.makeEquatableFunction(),
                macro.makeHashableFunction(),
                macro.makeCodingKeys(),
                macro.makeDecodeInitFunction(),
                macro.makeEncodeFunction(),
                macro.makeEmptyClass(),
            ]
        }
}

func decodeArrayExpr(_ labeledExpr: LabeledExprSyntax) throws -> [String] {
    guard let arrayExpr = labeledExpr.expression.as(ArrayExprSyntax.self) else {
        throw NSError(domain: "UsefulClassMacro requires argument conforms to ArrayExpr", code: 0)
    }
    
    var array: [String] = []
    for member in arrayExpr.elements {
        let expr: StringLiteralExprSyntax = member.expression.as(StringLiteralExprSyntax.self)!
        let segm: StringSegmentSyntax = expr.segments.first!.as(StringSegmentSyntax.self)!
        let memberName = segm.content.text
        
        array.append(memberName)
    }
    
    return array
}

@main
struct UsefulClassMacroPlugin: CompilerPlugin {
    let providingMacros: [SwiftSyntaxMacros.Macro.Type] = [
        UsefulClassMacro.self
    ]
}
