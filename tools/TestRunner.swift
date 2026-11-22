// Entry point for running the Swift Testing suite on macOS with only the
// Command Line Tools installed (used by tools/check-mac.sh; Xcode runs the
// same tests through its own runner and never compiles this file).
import Foundation
import Testing

@main
struct TestRunner {
    static func main() async {
        let code: CInt = await Testing.__swiftPMEntryPoint(passing: nil)
        exit(code)
    }
}
