import SwiftUI

struct HTMLHighlighterFactory: SourceHighlighterFactory {
    func construct(source: String, textStorage: NSTextStorage) -> SourceHighlighter {
        HTMLHighlighter(source: source, textStorage: textStorage)
    }
}

struct HTMLHighlighter: SourceHighlighter {
    var source: String;
    var textStorage: NSTextStorage;
    var lexer: HTMLLexer;
    var lexedTokens: [HTMLSymbol];
    
    init(source: String, textStorage: NSTextStorage) {
        self.source = source;
        self.textStorage = textStorage;
        self.lexer = HTMLLexer(source: source);
        self.lexedTokens = [];
    }
    
    func highlightAttr(attr: HTMLAttribute) {
        self.textStorage.addAttributes([
            .foregroundColor: self.attributeNameColor
        ], range: NSRange(attr.name, in: self.source));
        
        if let value = attr.value {
            self.textStorage.addAttributes([
                .foregroundColor: self.attributeValueColor
            ], range: NSRange(value, in: self.source));
        }
    }
    
    mutating func highlightSource() -> Bool {
        var tokens = 0;
        
        while let token = self.lexer.acceptSymbol() {
            tokens += 1;
            
            self.lexedTokens.append(token);
            
            switch token.type {
            case .Whitespace, .Text:
                textStorage.addAttributes([
                    .foregroundColor: self.textColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
            case let .Comment(text: text):
                textStorage.addAttributes([
                    .foregroundColor: self.commentColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
                textStorage.addAttributes([
                    .font: self.boldFont
                ], range: NSRange(text, in: source));
            case .Doctype:
                textStorage.addAttributes([
                    .foregroundColor: self.doctypeColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
            case let .XmlDecl(attributes: attrs):
                textStorage.addAttributes([
                    .foregroundColor: self.doctypeColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
                
                for attr in attrs {
                    self.highlightAttr(attr: attr);
                }
            case let .StartTag(name: tagname, attributes: attrs, selfClosing: _):
                textStorage.addAttributes([
                    .foregroundColor: self.tagColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
                textStorage.addAttributes([
                    .font: self.boldFont
                ], range: NSRange(tagname, in: source));
                
                for attr in attrs {
                    self.highlightAttr(attr: attr);
                }
            case let .EndTag(name: tagname):
                textStorage.addAttributes([
                    .foregroundColor: self.tagColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
                textStorage.addAttributes([
                    .font: self.boldFont
                ], range: NSRange(tagname, in: source));
            case .Error:
                textStorage.addAttributes([
                    .foregroundColor: self.errorColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
            }
            
            if tokens >= 100 {
                return false;
            }
        }
        
        return true;
    }
    
    mutating func sourceDidChange(newSource: String) {
        let prefix = self.source.commonPrefix(with: newSource);
        let prefixEnd = self.source.index(self.source.startIndex, offsetBy: prefix.count);
        var endOfTokens = 0;
        
        for (i, htoken) in self.lexedTokens.enumerated() {
            if htoken.range.upperBound <= prefixEnd {
                endOfTokens = i;
            }
        }
        
        if endOfTokens > 0 {
            if let lexPosition = self.lexedTokens[endOfTokens].range.upperBound.samePosition(in: newSource.unicodeScalars) {
                self.lexedTokens.removeSubrange(self.lexedTokens.index(0, offsetBy: endOfTokens)..<self.lexedTokens.endIndex);
                self.lexer = HTMLLexer(source: newSource);
                self.lexer.advance(to: lexPosition);
                
                self.source = newSource;
                return;
            }
        }
        
        //Fail case: could not resync lexer to new string or no common prefix
        self.lexer = HTMLLexer(source: newSource);
        self.lexedTokens = [];
        self.source = newSource;
    }
}

#if os(iOS)
extension HTMLHighlighter {
    var textColor: UIColor {
        .label
    }
    
    var commentColor: UIColor {
        .systemGreen
    }
    
    var doctypeColor: UIColor {
        .systemGray
    }
    
    var tagColor: UIColor {
        .systemBlue
    }
    
    var attributeNameColor: UIColor {
        .systemMint
    }
    
    var attributeValueColor: UIColor {
        .systemBrown
    }
    
    var errorColor: UIColor {
        .systemRed
    }
    
    var boldFont: UIFont {
        .monospacedSystemFont(ofSize: 16, weight: .bold)
    }
    
    var font: UIFont {
        .monospacedSystemFont(ofSize: 16, weight: .regular)
    }
}
#elseif os(macOS)
extension HTMLHighlighter {
    var textColor: NSColor {
        .textColor
    }
    
    var commentColor: NSColor {
        .systemGreen
    }
    
    var doctypeColor: NSColor {
        .systemGray
    }
    
    var tagColor: NSColor {
        .systemBlue
    }
    
    var attributeNameColor: NSColor {
        .systemMint
    }
    
    var attributeValueColor: NSColor {
        .systemBrown
    }
    
    var errorColor: NSColor {
        .systemRed
    }
    
    var boldFont: NSFont {
        .monospacedSystemFont(ofSize: 16, weight: .bold)
    }
    
    var font: NSFont {
        .monospacedSystemFont(ofSize: 16, weight: .regular)
    }
}
#endif
