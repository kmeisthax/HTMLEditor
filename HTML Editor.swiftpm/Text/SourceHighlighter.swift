import SwiftUI

/**
 * An object that can annotate source in a text view with its syntax.
 */
protocol SourceHighlighter {
    func highlightSource(source: String, textStorage: NSTextStorage);
}

struct TextHighlighter: SourceHighlighter {
    func highlightSource(source: String, textStorage: NSTextStorage) {
        return; //Text has no syntax to highlight.
    }
}
