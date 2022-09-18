import SwiftUI

/**
 * Factory protocol which exists to avoid having to put generic class arguments on objc classes
 */
protocol SourceHighlighterFactory {
    func construct(source: String, textStorage: NSTextStorage) -> SourceHighlighter;
}

/**
 * An object that can annotate source in a text view with its syntax.
 *
 * Usage:
 *
 * - Initialize a Source Highlighter with the source string and the target text storage.
 * - Repeatedly call highlightSource until done.
 * - If source changes, dispose of the highlighter and construct a new one.
 */
protocol SourceHighlighter {
    /**
     * Annotate some amount of source with text colors or bold font.
     *
     * Method is intended to be called repeatedly until it returns true,
     * indicating that annotation has completed.
     */
    mutating func highlightSource() -> Bool;
}

struct TextHighlighterFactory: SourceHighlighterFactory {
    func construct(source: String, textStorage: NSTextStorage) -> SourceHighlighter {
        TextHighlighter()
    }
}

struct TextHighlighter: SourceHighlighter {
    func highlightSource() -> Bool {
        return true; //Text has no syntax to highlight.
    }
}
