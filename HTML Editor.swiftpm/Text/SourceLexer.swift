import SwiftUI

/**
 * A structure that allows parsing a string to obtain tokens.
 * 
 * Lexers must minimally maintain a reference to the source string
 * and an index into it. We use unicode scalar indicies as many specs
 * are written in terms of codepoints rather than characters.
 * 
 * Lexers get a handful of convenience methods that allow advancing
 * the lexer index based on the presence of characters or codepoints
 * in the string. These can be broken down into one of two
 * categories:
 * 
 *  - Consumers, which unconditionally take characters from the
 *    source string until a condition is violated
 * 
 *  - Accepters, which only take characters from a string if some
 *    condition matches and leave the index alone otherwise.
 * 
 * Your lexer will almost certainly consist of accept methods that
 * yield some kind of token type (e.g. MySymbol) and leave the lexer
 * alone otherwise. The pattern for implementing any acceptor is:
 * 
 *  - Copy the current parsing index, we'll call this "checkpoint"
 * 
 *  - Accept or consume the source string as necessary to recognize
 *    the underlying text pattern
 * 
 *  - Whenever an accept method fails, restore the checkpoint and
 *    return nil.
 * 
 *  - Whenever the pattern is met, return your symbol.
 */
protocol SourceLexer {
    var source: String { get };
    var parsingIndex: String.UnicodeScalarIndex { get set };
}

extension SourceLexer {
    /**
     * Advance the lexer to a specific position.
     */
    mutating func advance(to: String.UnicodeScalarView.Index) {
        self.parsingIndex = to;
    }
    
    /**
     * Convert a pair of Unicode Scalar Value indices
     * into a Swift character range.
     * 
     * The ranges must originate from the source string
     * for this lexer.
     */
    func acceptedRange(_ start: String.UnicodeScalarIndex, _ end: String.UnicodeScalarIndex) -> Range<String.Index>? {
        let rangeStart = start.samePosition(in: self.source);
        let rangeEnd = end.samePosition(in: self.source);
        
        guard let rangeStart = rangeStart else {
            return nil;
        }
        guard let rangeEnd = rangeEnd else {
            return nil;
        }
        
        return rangeStart..<rangeEnd;
    }
    
    /**
     * Consume one or more String characters satisfying a
     * given condition.
     * 
     * Returns a range if at least one character was
     * accepted, and updates the parsing index
     * appropriately.
     */
    mutating func consume(charCond: (String.Element) -> Bool) -> Range<String.Index>? {
        var end = self.parsingIndex;
        let chars = self.source[end...];
        
        for idx in chars.indices {
            if charCond(chars[idx]) {
                continue;
            }
            
            end = idx;
            break;
        }
        
        if end > self.parsingIndex {
            let rangeStart = self.parsingIndex;
            
            self.parsingIndex = end;
            
            return self.acceptedRange(rangeStart, end);
        }
        
        return nil;
    }
    
    /**
     * Consume one or more Unicode scalar values satisfying
     * a given condition.
     * 
     * Returns a range if at least one scalar was accepted,
     * and updates the parsing index appropriately.
     */
    mutating func consume(scalarCond: (String.UnicodeScalarView.Element) -> Bool) -> Range<String.Index>? {
        var end = self.parsingIndex;
        let chars = self.source.unicodeScalars[end...];
        
        for idx in chars.indices {
            if scalarCond(chars[idx]) {
                continue;
            }
            
            end = idx;
            break;
        }
        
        if end > self.parsingIndex {
            let rangeStart = self.parsingIndex;
            
            self.parsingIndex = end;
            
            return self.acceptedRange(rangeStart, end);
        }
        
        return nil;
    }
    
    mutating func accept(substring: String) -> Range<String.Index>? {
        guard let charsStart = self.parsingIndex.samePosition(in: self.source) else { return nil };
        guard let charsEnd = self.source.index(charsStart, offsetBy: substring.count, limitedBy: self.source.endIndex) else { return nil };
        
        let chars = self.source[charsStart..<charsEnd];
        
        let matches = chars == substring;
        
        if matches {
            self.parsingIndex = charsEnd;
            return self.acceptedRange(charsStart, charsEnd);
        }
        
        return nil;
    }
    
    /**
     * Consume all characters up until a given substring.
     * 
     * The returned range contains the consumed string only
     * and not the substring. The end index including the
     * substring will be written to self.parsingIndex.
     */
    mutating func consume(until: String) -> Range<String.Index>? {
        guard let charsStart = self.parsingIndex.samePosition(in: self.source) else { return nil; }
        
        let searchString = self.source[charsStart...];
        if let foundRange = searchString.range(of: until) {
            self.parsingIndex = foundRange.upperBound;
            return self.acceptedRange(charsStart, foundRange.lowerBound);
        }
        
        return nil;
    }
}
