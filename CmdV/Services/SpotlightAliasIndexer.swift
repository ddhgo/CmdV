import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

final class SpotlightAliasIndexer {
    private let uniqueIdentifier = "com.cmdv.app.search.alias"
    private let domainIdentifier = "com.cmdv.app"

    func indexAppAliasKeywords() {
        guard CSSearchableIndex.isIndexingAvailable() else {
            return
        }

        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.application.identifier)
        attributeSet.title = "CmdV"
        attributeSet.displayName = "CmdV"
        attributeSet.contentDescription = "CmdV clipboard history app"
        attributeSet.contentURL = Bundle.main.bundleURL
        attributeSet.keywords = [
            "CmdV",
            "cmdv",
            "클립보드",
            "clipboard",
            "층ㅍ",
            "ㅊㅡㅇㅍ"
        ]

        let item = CSSearchableItem(
            uniqueIdentifier: uniqueIdentifier,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { _ in }
    }
}
