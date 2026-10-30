import AppKit
import ImageIO
import UniformTypeIdentifiers

@main
@MainActor
struct ClipboardPNGTests {
    static var failures = 0
    static var passes = 0

    static func main() async {
        let dir = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let tiff = tiffFixture(width: 600, height: 400)

        // `sips` stands in for the helper: a real TIFF→PNG re-encode, at the helper's argv.
        let converted = await ClipboardPNGRunner.png(
            fromTIFF: tiff, helper: script(in: dir, "sips -s format png \"$2\" --out \"$3\" >/dev/null"))
        expect(
            converted.flatMap(pngSize) == CGSize(width: 600, height: 400),
            "a TIFF comes back as a PNG of the same size")

        let failed = await ClipboardPNGRunner.png(fromTIFF: tiff, helper: script(in: dir, "exit 1"))
        expect(failed == nil, "a failing helper yields nothing, so the caller encodes itself")

        let missing = await ClipboardPNGRunner.png(
            fromTIFF: tiff, helper: dir.appendingPathComponent("missing-helper"))
        expect(missing == nil, "a missing helper yields nothing")

        let start = ContinuousClock.now
        let stuck = await ClipboardPNGRunner.png(
            fromTIFF: tiff, helper: script(in: dir, "sleep 30"), timeout: .milliseconds(300))
        expect(stuck == nil && start.duration(to: .now) < .seconds(5), "a stuck helper times out")

        let leftovers =
            (try? FileManager.default.contentsOfDirectory(
                atPath: FileManager.default.temporaryDirectory.path))?
            .filter { $0.hasPrefix("tinycast-clipboard-") } ?? []
        expect(leftovers.isEmpty, "no TIFF or PNG is left in the temporary directory")

        print("\(passes)/\(passes + failures) passed")
        if failures > 0 { exit(1) }
    }

    // MARK: - Fixtures

    static func script(in dir: URL, _ body: String) -> URL {
        let url = dir.appendingPathComponent("helper-\(UUID().uuidString).sh")
        try? "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    /// Uncompressed, as AppKit puts an image on the pasteboard.
    static func tiffFixture(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.tiffRepresentation(using: .none, factor: 0)!
    }

    static func pngSize(_ data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetType(source) as String? == UTType.png.identifier,
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return CGSize(width: image.width, height: image.height)
    }

    static func scratchDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard-png-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }
}
