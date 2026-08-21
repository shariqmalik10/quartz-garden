import Foundation
import XCTest
@testable import GardenDrop

final class CaptureMarkdownTests: XCTestCase {
    func testRendersObsidianFrontmatterAndThought() {
        let draft = CaptureDraft(
            id: "gd-20260814-demo",
            title: "A title with \"quotes\"",
            source: CaptureSource(
                type: .web,
                title: "A title with \"quotes\"",
                url: URL(string: "https://example.com/article"),
                domain: "example.com",
                excerpt: nil,
                capturedText: nil,
                attachment: nil
            ),
            thought: "Keep the source, then add the smallest useful thought.",
            areaName: "Design & Interaction",
            visibility: .garden,
            capturedAt: Date(timeIntervalSince1970: 1_755_178_200),
            metadataStatus: .complete
        )

        let markdown = CaptureMarkdownRenderer().render(draft, attachmentRelativePath: nil)

        XCTAssertTrue(markdown.contains("id: \"gd-20260814-demo\""))
        XCTAssertTrue(markdown.contains("title: \"A title with "))
        XCTAssertTrue(markdown.contains("\\\"quotes\\\""))
        XCTAssertTrue(markdown.contains("source: \"https://example.com/article\""))
        XCTAssertTrue(markdown.contains("area: \"[[Design & Interaction]]\""))
        XCTAssertTrue(markdown.contains("visibility: garden"))
        XCTAssertTrue(markdown.contains("attachments: []"))
        XCTAssertTrue(markdown.contains("## Thought\n\nKeep the source"))
        XCTAssertTrue(markdown.contains("Area: [[Design & Interaction]]"))
        XCTAssertTrue(markdown.contains("[Open original](<https://example.com/article>)"))
    }

    func testRendersAttachmentWikilinkAndCapturedText() {
        let source = CaptureSource(
            type: .text,
            title: "Copied text",
            url: nil,
            domain: nil,
            excerpt: "A short excerpt",
            capturedText: "The exact copied passage stays available.",
            attachment: nil
        )
        let draft = CaptureDraft(
            id: "gd-20260814-text",
            title: "Copied text",
            source: source,
            thought: "",
            areaName: "Personal",
            visibility: .privateArea,
            capturedAt: Date(timeIntervalSince1970: 1_755_178_200),
            metadataStatus: .complete
        )

        let markdown = CaptureMarkdownRenderer().render(
            draft,
            attachmentRelativePath: "Attachments/Captures/gd-20260814-text/preview.txt"
        )

        XCTAssertTrue(markdown.contains("visibility: private"))
        XCTAssertTrue(markdown.contains("attachments:"))
        XCTAssertTrue(markdown.contains("[[Attachments/Captures/gd-20260814-text/preview.txt]]"))
        XCTAssertTrue(markdown.contains("_No thought added._"))
        XCTAssertTrue(markdown.contains("## Captured text"))
        XCTAssertTrue(markdown.contains("The exact copied passage stays available."))
    }
}
