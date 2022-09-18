import SwiftUI

struct Attribute {
    var name: Range<String.Index>;
    var value: Range<String.Index>?;
}

enum LexType {
    case Whitespace
    case Text
    case Comment(text: Range<String.Index>)
    case Doctype
    case Error
    case StartTag(name: Range<String.Index>, attributes: [Attribute], selfClosing: Bool)
    case EndTag(name: Range<String.Index>)
}

struct Symbol {
    var type: LexType
    var range: Range<String.Index>
}

struct HTMLLexer {
    var source: String;
    var parsingIndex: String.UnicodeScalarIndex;
    
    init(source: String) {
        self.source = source;
        self.parsingIndex = source.startIndex.samePosition(in: self.source.unicodeScalars)!;
    }
    
    private func acceptedRange(_ start: String.UnicodeScalarIndex, _ end: String.UnicodeScalarIndex) -> Range<String.Index>? {
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
     * Accept an ASCII case-insensitive substring at the
     * current position.
     * 
     * The given substring to search must already be ASCII
     * lowercased.
     */
    mutating func accept(asciiCaseInsensitiveSubstring: String) -> Range<String.Index>? {
        let checkpoint = self.parsingIndex;
        let vals = asciiCaseInsensitiveSubstring.unicodeScalars;
        var substringPosition = vals.startIndex;
        
        let consumedRange = self.consume(scalarCond: { c in
            var cval_toLower = c.value;
            if cval_toLower >= 0x41 && cval_toLower < 0x60 {
                cval_toLower += 0x20;
            }
            
            if (substringPosition == vals.endIndex) {
                return false;
            }
            
            if (vals[substringPosition].value == cval_toLower) {
                substringPosition = vals.index(substringPosition, offsetBy: 1);
                return true;
            } else {
                return false;
            }
        });
        
        if let consumedRange = consumedRange, substringPosition == vals.endIndex {
            return consumedRange;
        } else {
            self.parsingIndex = checkpoint;
            return nil;
        }
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
    
    /**
     * Consume a tag name, without whitespace.
     */
    mutating func consumeTagName() -> Range<String.Index>? {
        self.consume(scalarCond: { elem in
            let c = elem.value;
            
            // Exclude controls, space, either quote kind, greater than, forward-slash, equals, and noncharacters
            return c > 0x20 && c != 0x22 && c != 0x27 && c != 0x3E && c != 0x2F && c != 0x3D && !(c >= 0x7F && c <= 0x9F) && !(c >= 0xFDD0 && c <= 0xFDEF) && c & 0xFFFE != 0xFFFE;
        });
    }
    
    /**
     * Consume an attribute name, without whitespace.
     */
    mutating func consumeAttributeName() -> Range<String.Index>? {
        self.consume(scalarCond: { elem in 
            let c = elem.value;
            
            // Exclude controls, space, either quote kind, greater than, forward-slash, equals, and noncharacters 
            return c > 0x20 && c != 0x22 && c != 0x27 && c != 0x3E && c != 0x2F && c != 0x3D && !(c >= 0x7F && c <= 0x9F) && !(c >= 0xFDD0 && c <= 0xFDEF) && c & 0xFFFE != 0xFFFE;
        });
    }
    
    /**
     * Consume an unquoted attribute value.
     */
    mutating func consumeUnquotedAttributeValue() -> Range<String.Index>? {
        //TODO: Impl ambiguous ampersand rejection
        self.consume(scalarCond: { elem in
            let c = elem.value;
            
            return c != 0x9 && c != 0xA && c != 0xC && c != 0xD && c != 0x20 && c != 0x22 && c != 0x27 && c != 0x3D && c != 0x3C && c != 0x3E && c != 0x60;
        })
    }
    
    /**
     * Accept a quoted string.
     * 
     * If the string at the parsing index is a valid quoted
     * string, this function returns the range of the
     * contents of the string.
     * 
     * The parsing index will point to the end of the quoted
     * string; which should be one after the end of the
     * returned range.
     * 
     * Otherwise it returns nil and does not advance the
     * parsing index.
     */
    mutating func acceptQuotedString() -> Range<String.Index>? {
        let checkpoint = self.parsingIndex;
        guard let quoteStart = self.accept(substring: "\"") ?? self.accept(substring: "'") else {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        //TODO: Does HTML support escaped quotes?
        let quoteKind = self.source[quoteStart.lowerBound];
        let _ = self.consume(until: String(quoteKind));
        
        guard let stringEnd = self.parsingIndex.samePosition(in: self.source) else {
            self.parsingIndex = checkpoint;
            return nil;
        };
        
        let quoteEnd = self.source.index(before: stringEnd);
        
        if self.source[quoteEnd] != quoteKind {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        return quoteStart.upperBound..<quoteEnd;
    }
    
    /**
     * Consume a malformed tag.
     * 
     * Returns an Error Symbol starting from the given
     * checkpoint up to the end of the malformed tag.
     * 
     * In the event of invalid ranges, resets the checkpoint
     * and returns nil.
     */
    mutating func consumeMalformedTag(from checkpoint: String.UnicodeScalarIndex) -> Symbol? {
        let _ = self.consume(until: ">");
        
        guard let accepted = self.acceptedRange(checkpoint, self.parsingIndex) else {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        return Symbol(type: .Error, range: accepted);
    }
    
    /**
     * Consume any amount of whitespace.
     * 
     * If any whitespace was consumed, it will advance the
     * parsing index and return a Symbol.
     */
    mutating func consumeWhitespace() -> Symbol? {
        guard let range = self.consume(scalarCond: { char in
            let v = char.value;
            return v == 9 || v == 0xA || v == 0xC || v == 0xD || v == 0x20;
        }) else { return nil };
        
        return Symbol(type: .Whitespace, range: range);
    }
    
    /**
     * Accept any amount of text.
     * 
     * Returns a Symbol if any amount of text was accepted.
     */
    mutating func consumeText() -> Symbol? {
        guard let range = self.consume(charCond: { char in
            char != "<" && char != ">"
        }) else { return nil; }
        
        return Symbol(type: .Text, range: range);
    }
    
    /**
     * Accept a comment.
     * 
     * Returns a Symbol if a comment was accepted.
     */
    mutating func acceptComment() -> Symbol? {
        let checkpoint = self.parsingIndex;
        guard self.accept(substring: "<!--") != nil else {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        guard let consumedRange = self.consume(until: "-->") else {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        guard let acceptedRange = self.acceptedRange(checkpoint, self.parsingIndex) else {
            self.parsingIndex = checkpoint;
            return nil;
        };
        
        let commentString = self.source[consumedRange.lowerBound..<consumedRange.upperBound];
        
        if commentString.starts(with: ">") || commentString.starts(with: "->") || commentString.contains("<!--") || commentString.contains("-->") || commentString.contains("--!>") || commentString.hasSuffix("<!-") {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        return Symbol(type: .Comment(text: consumedRange), range: acceptedRange);
    }
    
    mutating func acceptDoctype() -> Symbol? {
        let checkpoint = self.parsingIndex;
        
        guard let start = self.accept(asciiCaseInsensitiveSubstring: "<!doctype") else {
            self.parsingIndex = checkpoint;
            return nil;
        };
        
        if self.consumeWhitespace() == nil {
            return self.consumeMalformedTag(from: checkpoint);
        }
        
        if self.accept(asciiCaseInsensitiveSubstring: "html") == nil {
            return self.consumeMalformedTag(from: checkpoint);
        }
        
        let ws = self.consumeWhitespace();
        
        if let endRange = self.accept(substring: ">") {
            return Symbol(type: .Doctype, range: start.lowerBound..<endRange.upperBound);
        } else if ws == nil {
            return self.consumeMalformedTag(from: checkpoint);
        }
        
        //HTML5 says this should only be "SYSTEM"
        if self.consumeAttributeName() == nil {
            return self.consumeMalformedTag(from: checkpoint);
        }
        
        if self.consumeWhitespace() == nil {
            return self.consumeMalformedTag(from: checkpoint);
        }
        
        //HTML5 says this should only be "about:legacy-compat"
        if self.acceptQuotedString() == nil {
            return self.consumeMalformedTag(from: checkpoint);
        }
        
        let _ = self.consumeWhitespace();
        
        if let endRange = self.accept(substring: ">") {
            return Symbol(type: .Doctype, range: start.lowerBound..<endRange.upperBound);
        }
        
        return self.consumeMalformedTag(from: checkpoint);
    }
    
    /**
     * Accept a start tag.
     * 
     * Returns nil if there is no start tag at the current
     * position. Otherwise, returns either a StartTag
     * symbol or an Error symbol.
     */
    mutating func acceptStartTag() -> Symbol? {
        let checkpoint = self.parsingIndex;
        
        guard let start = self.accept(substring: "<") else {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        guard let tagname = self.consumeTagName() else {
            return self.consumeMalformedTag(from: checkpoint);
        }
        
        var attributes: Array<Attribute> = [];
        
        if self.consumeWhitespace() != nil {
            while let name = self.consumeAttributeName() {
                let _ = self.consumeWhitespace();
                
                if self.accept(substring: "=") != nil {
                    let _ = self.consumeWhitespace();
                    
                    if let value = self.consumeUnquotedAttributeValue() {
                        attributes.append(Attribute(name: name, value: value))
                    } else if let value = self.acceptQuotedString() {
                        attributes.append(Attribute(name: name, value: value))
                    } else {
                        //TODO: quoted
                        return self.consumeMalformedTag(from: checkpoint);
                    }
                } else {
                    attributes.append(Attribute(name: name));
                }
                
                let _ = self.consumeWhitespace();
            }
        }
        
        let selfclosing = self.accept(substring: "/") != nil;
        guard let end = self.accept(substring: ">") else {
            return self.consumeMalformedTag(from: checkpoint);
        };
        
        return Symbol(type: .StartTag(name: tagname, attributes: attributes, selfClosing: selfclosing), range: start.lowerBound..<end.upperBound);
    }
    
    /**
     * Accept an end tag.
     * 
     * Returns nil if there is no start tag at the current
     * position. Otherwise, returns either a StartTag
     * symbol or an Error symbol.
     */
    mutating func acceptEndTag() -> Symbol? {
        let checkpoint = self.parsingIndex;
        
        guard let start = self.accept(substring: "</") else {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        guard let tagname = self.consumeTagName() else {
            print(self.source[checkpoint..<self.parsingIndex]);
            return self.consumeMalformedTag(from: checkpoint);
        }
        
        let _ = self.consumeWhitespace();
        
        guard let end = self.accept(substring: ">") else {
            print(self.source[checkpoint..<self.parsingIndex]);
            return self.consumeMalformedTag(from: checkpoint);
        };
        
        return Symbol(type: .EndTag(name: tagname), range: start.lowerBound..<end.upperBound);
    }
    
    /**
     * Accept any valid symbol.
     * 
     * Returns nil if there is no valid symbol or if we've
     * reached the end of the string.
     */
    mutating func acceptSymbol() -> Symbol? {
        if let doctype = self.acceptDoctype() {
            return doctype;
        } else if let comment = self.acceptComment() {
            return comment;
        } else if let endtag = self.acceptEndTag() {
            return endtag;
        } else if let starttag = self.acceptStartTag() {
            return starttag;
        } else if let whitespace = self.consumeWhitespace() {
            return whitespace;
        } else if let text = self.consumeText() {
            return text;
        } else {
            return nil;
        }
    }
}
