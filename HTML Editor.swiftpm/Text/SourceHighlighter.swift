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
    
    /**
     * Indicate that the source code changed.
     * 
     * After calling this function, you should repeatedly call highlightSource
     * again.
     * 
     * Source highlighters are responsible for retaining text annotations for
     * parts of the source that did not change, and repairing annotations that
     * did change.
     */
    mutating func sourceDidChange(newSource: String);
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
    
    func sourceDidChange(newSource: String) {
        //We don't highlight so we don't care about the source changing.
    }
}
