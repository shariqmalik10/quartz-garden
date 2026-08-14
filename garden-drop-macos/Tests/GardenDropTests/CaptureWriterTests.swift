import Foundation
import XCTest
@testable import GardenDrop

final class CaptureWriterTests: XCTestCase {
    func testWritesNoteAndAttachmentIntoVaultContract() async throws {
        let vaultURL = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let attachment = CaptureAttachment(
            fileName: "preview.webp",
            data: Data([0x47, 0x44, 0x01]),
            mimeType: "image/webp"
        )
        let source = CaptureSource(
            type: .image,
            title: "A saved image",
            url: URL(string: "https://example.com/image"),
            domain: "example.com",
            excerpt: "A visual reference.",
            capturedText: nil,
            attachment: attachment
        )
        let draft = CaptureDraft(
            id: "gd-20260814-attachment",
            title: "A saved image",
            source: source,
            thought: "This image is useful as a reference.",
            areaName: "Design & Interaction",
            visibility: .garden,
            capturedAt: Date(timeIntervalSince1970: 1_755_178_200),
            metadataStatus: .complete
        )

        let result = try await CaptureWriter(vaultRoot: vaultURL).write(draft)

        let expectedNote = vaultURL
            .appendingPathComponent("Areas/Design & Interaction/Captures/gd-20260814-attachment.md")
        let expectedAttachment = vaultURL
            .appendingPathComponent("Attachments/Captures/gd-20260814-attachment/preview.webp")

        XCTAssertEqual(result.noteURL, expectedNote)
        XCTAssertEqual(result.attachmentURL, expectedAttachment)
        XCTAssertEqual(try Data(contentsOf: expectedAttachment), attachment.data)

        let markdown = try String(contentsOf: expectedNote, encoding: .utf8)
        XCTAssertTrue(markdown.contains("metadata_status: complete"))
        XCTAssertTrue(markdown.contains("[[Attachments/Captures/gd-20260814-attachment/preview.webp]]"))
        XCTAssertTrue(markdown.contains("This image is useful as a reference."))
    }

    func testRejectsDuplicateCaptureIDWithoutOverwritingTheNote() async throws {
        let vaultURL = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let draft = CaptureDraft(
            id: "gd-20260814-duplicate",
            title: "Duplicate",
            source: .sample,
            thought: "The first write should remain.",
            areaName: "Personal",
            visibility: .privateArea,
            capturedAt: Date(timeIntervalSince1970: 1_755_178_200),
            metadataStatus: .complete
        )
        let writer = CaptureWriter(vaultRoot: vaultURL)

        _ = try await writer.write(draft)

        do {
            _ = try await writer.write(draft)
            XCTFail("Expected a duplicate capture error")
        } catch let error as CaptureWriteError {
            guard case .noteAlreadyExists = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRejectsUnsafeAreaAndAttachmentNames() async throws {
        let vaultURL = temporaryVaultURL()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let unsafeAreaDraft = CaptureDraft(
            id: "gd-20260814-unsafe",
            title: "Unsafe",
            source: .sample,
            thought: "",
            areaName: "../Inbox",
            visibility: .privateArea,
            capturedAt: Date(),
            metadataStatus: .complete
        )

        do {
            _ = try await CaptureWriter(vaultRoot: vaultURL).write(unsafeAreaDraft)
            XCTFail("Expected an invalid area error")
        } catch let error as CaptureWriteError {
            guard case .invalidPathComponent = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let unsafeAttachment = CaptureAttachment(
            fileName: "../preview.png",
            data: Data([0x01]),
            mimeType: "image/png"
        )
        let unsafeAttachmentDraft = CaptureDraft(
            id: "gd-20260814-unsafe-attachment",
            title: "Unsafe attachment",
            source: CaptureSource(
                type: .image,
                title: "Unsafe attachment",
                url: nil,
                domain: nil,
                excerpt: nil,
                capturedText: nil,
                attachment: unsafeAttachment
            ),
            thought: "",
            areaName: "Personal",
            visibility: .privateArea,
            capturedAt: Date(),
            metadataStatus: .complete
        )

        do {
            _ = try await CaptureWriter(vaultRoot: vaultURL).write(unsafeAttachmentDraft)
            XCTFail("Expected an invalid attachment error")
        } catch let error as CaptureWriteError {
            guard case .invalidPathComponent = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private func temporaryVaultURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenDropTests-\(UUID().uuidString)", isDirectory: true)
    }
}
