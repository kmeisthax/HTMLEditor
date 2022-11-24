import SwiftUI

struct HTMLAttribute {
    var name: Range<String.Index>;
    var value: Range<String.Index>?;
}

enum HTMLLexType {
    case Whitespace
    case Text
    case Comment(text: Range<String.Index>)
    case Doctype
    case XmlDecl(attributes: [HTMLAttribute])
    case Error
    case StartTag(name: Range<String.Index>, attributes: [HTMLAttribute], selfClosing: Bool)
    case EndTag(name: Range<String.Index>)
}

struct HTMLSymbol {
    var type: HTMLLexType
    var range: Range<String.Index>
}

struct HTMLLexer: SourceLexer {
    var source: String;
    var parsingIndex: String.UnicodeScalarIndex;
    
    init(source: String) {
        self.source = source;
        self.parsingIndex = source.startIndex.samePosition(in: self.source.unicodeScalars)!;
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
    mutating func consumeMalformedTag(from checkpoint: String.UnicodeScalarIndex) -> HTMLSymbol? {
        let _ = self.consume(until: ">");
        
        guard let accepted = self.acceptedRange(checkpoint, self.parsingIndex) else {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        return HTMLSymbol(type: .Error, range: accepted);
    }
    
    /**
     * Consume any amount of whitespace.
     * 
     * If any whitespace was consumed, it will advance the
     * parsing index and return a Symbol.
     */
    mutating func consumeWhitespace() -> HTMLSymbol? {
        guard let range = self.consume(scalarCond: { char in
            let v = char.value;
            return v == 9 || v == 0xA || v == 0xC || v == 0xD || v == 0x20;
        }) else { return nil };
        
        return HTMLSymbol(type: .Whitespace, range: range);
    }
    
    /**
     * Accept any amount of text.
     * 
     * Returns a Symbol if any amount of text was accepted.
     */
    mutating func consumeText() -> HTMLSymbol? {
        guard let range = self.consume(charCond: { char in
            char != "<" && char != ">"
        }) else { return nil; }
        
        return HTMLSymbol(type: .Text, range: range);
    }
    
    /**
     * Accept a comment.
     * 
     * Returns a Symbol if a comment was accepted.
     */
    mutating func acceptComment() -> HTMLSymbol? {
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
        
        return HTMLSymbol(type: .Comment(text: consumedRange), range: acceptedRange);
    }
    
    mutating func acceptDoctype() -> HTMLSymbol? {
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
            return HTMLSymbol(type: .Doctype, range: start.lowerBound..<endRange.upperBound);
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
            return HTMLSymbol(type: .Doctype, range: start.lowerBound..<endRange.upperBound);
        }
        
        return self.consumeMalformedTag(from: checkpoint);
    }
    
    /**
     * Accept an HTML/XML attribute.
     *
     * The bool parameter is true if the attribute is malformed.
     */
    mutating func acceptAttribute() -> (HTMLAttribute?, Bool) {
        let checkpoint = self.parsingIndex;
        
        guard let name = self.consumeAttributeName() else { return (nil, false) };
        let _ = self.consumeWhitespace();
            
        if self.accept(substring: "=") != nil {
            let _ = self.consumeWhitespace();
            
            if let value = self.consumeUnquotedAttributeValue() {
                return (HTMLAttribute(name: name, value: value), false);
            } else if let value = self.acceptQuotedString() {
                return (HTMLAttribute(name: name, value: value), false);
            } else {
                self.parsingIndex = checkpoint;
                return (nil, true);
            }
        } else {
            return (HTMLAttribute(name: name), false);
        }
    }
    
    /**
     * Accept a start tag.
     * 
     * Returns nil if there is no start tag at the current
     * position. Otherwise, returns either a StartTag
     * symbol or an Error symbol.
     */
    mutating func acceptStartTag() -> HTMLSymbol? {
        let checkpoint = self.parsingIndex;
        
        guard let start = self.accept(substring: "<") else {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        guard let tagname = self.consumeTagName() else {
            return self.consumeMalformedTag(from: checkpoint);
        }
        
        var attributes: Array<HTMLAttribute> = [];
        
        if self.consumeWhitespace() != nil {
            while true {
                let (attr, malformed) = self.acceptAttribute();
                if malformed {
                    return self.consumeMalformedTag(from: checkpoint);
                }
                
                guard let attr = attr else { break; }
                
                attributes.append(attr);
                
                let _ = self.consumeWhitespace();
            }
        }
        
        let selfclosing = self.accept(substring: "/") != nil;
        guard let end = self.accept(substring: ">") else {
            return self.consumeMalformedTag(from: checkpoint);
        };
        
        return HTMLSymbol(type: .StartTag(name: tagname, attributes: attributes, selfClosing: selfclosing), range: start.lowerBound..<end.upperBound);
    }
    
    mutating func acceptXmlDecl() -> HTMLSymbol? {
        let checkpoint = self.parsingIndex;
        
        guard let start = self.accept(substring: "<?xml") else {
            self.parsingIndex = checkpoint;
            return nil;
        }
        
        let _ = self.consumeWhitespace();
        
        var attributes: Array<HTMLAttribute> = [];
        var end = self.accept(substring: "?>");
        
        while end == nil {
            let (attr, malformed) = self.acceptAttribute();
            if malformed {
                return self.consumeMalformedTag(from: checkpoint);
            }
            
            guard let attr = attr else { break; }
            
            attributes.append(attr);
            
            let _ = self.consumeWhitespace();
            end = self.accept(substring: "?>");
        }
        
        return HTMLSymbol(type: .XmlDecl(attributes: attributes), range: start.lowerBound..<end!.upperBound);
    }
    
    /**
     * Accept an end tag.
     * 
     * Returns nil if there is no start tag at the current
     * position. Otherwise, returns either a StartTag
     * symbol or an Error symbol.
     */
    mutating func acceptEndTag() -> HTMLSymbol? {
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
        
        return HTMLSymbol(type: .EndTag(name: tagname), range: start.lowerBound..<end.upperBound);
    }
    
    /**
     * Accept any valid symbol.
     * 
     * Returns nil if there is no valid symbol or if we've
     * reached the end of the string.
     */
    mutating func acceptSymbol() -> HTMLSymbol? {
        if let doctype = self.acceptDoctype() {
            return doctype;
        } else if let xmldecl = self.acceptXmlDecl() {
            return xmldecl;
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
