import AEXML
import Foundation
import PathKit

extension XCScheme {
    public final class Management: Writable, Equatable {
        // MARK: - Attributes

        public var userState: SchemeUserState
        public var suppressBuildableAutocreation: SuppressBuildableAutocreation

        // MARK: - Init

        public init(schemes: [XCScheme], targets: [PBXTarget] = []) {
            self.userState = SchemeUserState(schemes: schemes)
            self.suppressBuildableAutocreation = .init(
                targetNames: targets.map { $0.name })
        }

        init(path: Path) throws {
            guard let document = try? AEXMLDocument(
                xml: try Management.plistPath(from: path).read()) else {
                let basePath = Path(path.string.replacingOccurrences(
                    of: XCUserData.schemesPath.string, with: ""))
                let sharedData = try XCSharedData(path: basePath)

                let userSchemes = try XCUserData.schemes(from: path)
                let sharedSchemes = sharedData.schemes
                userSchemes.forEach { $0.isShared = false }
                sharedSchemes.forEach { $0.isShared = true }

                let pbxProj = try PBXProj.from(path: basePath)
                let sharedNames = sharedSchemes.map { $0.name }
                let schemeNames = pbxProj.nativeTargets.map { target in
                    return target.reference.value
                }

                userState = SchemeUserState(
                    schemes: sharedSchemes
                )
                suppressBuildableAutocreation = .init(
                    targetNames: schemeNames.filter { name in
                        let targetName = name.components(separatedBy: "::").last
                        return !sharedNames.contains(targetName ?? "")
                    }
                )
                return
            }
            userState = try SchemeUserState(element: document[SchemeUserState.isa])
            suppressBuildableAutocreation = try SuppressBuildableAutocreation(element: document["SuppressBuildableAutocreation"])
        }

        // MARK: - Writable

        public func write(path: Path, override: Bool) throws {
            let document: AEXMLDocument = .plist

            let elements: AEXMLElement = .dict
            elements.addChildren(userState.xmlElements())
            elements.addChildren(
                suppressBuildableAutocreation.xmlElements()
            )

            document.root.addChild(elements)

            let plist = document.xmlPlist
            try Management.plistPath(from: path).write(plist)
        }

        // MARK: - Equatable

        public static func ==(lhs: Management, rhs: Management) -> Bool {
            return lhs.userState == rhs.userState &&
                lhs.suppressBuildableAutocreation == rhs.suppressBuildableAutocreation
        }
    }
}

extension XCScheme.Management {
    private static func plistPath(from path: Path) -> Path {
        let managementName = XCScheme.Management.isa.lowercased()
        let xcschemeName = XCScheme.isa.lowercased()
        return path + XCUserData.schemesPath
            + Path("\(xcschemeName + managementName).plist")
    }
}
