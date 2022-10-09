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
    
    init(source: String, textStorage: NSTextStorage) {
        self.source = source;
        self.textStorage = textStorage;
        self.lexer = HTMLLexer(source: source);
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
            
            switch token.type {
            case .Whitespace, .Text:
                textStorage.addAttributes([
                    .foregroundColor: self.textColor
                ], range: NSRange(token.range, in: source));
            case let .Comment(text: text):
                textStorage.addAttributes([
                    .foregroundColor: self.commentColor
                ], range: NSRange(token.range, in: source));
                textStorage.addAttributes([
                    .font: self.boldFont
                ], range: NSRange(text, in: source));
            case .Doctype:
                textStorage.addAttributes([
                    .foregroundColor: self.doctypeColor
                ], range: NSRange(token.range, in: source));
            case let .XmlDecl(attributes: attrs):
                textStorage.addAttributes([
                    .foregroundColor: self.doctypeColor
                ], range: NSRange(token.range, in: source));
                
                for attr in attrs {
                    self.highlightAttr(attr: attr);
                }
            case let .StartTag(name: tagname, attributes: attrs, selfClosing: _):
                textStorage.addAttributes([
                    .foregroundColor: self.tagColor
                ], range: NSRange(token.range, in: source));
                textStorage.addAttributes([
                    .font: self.boldFont
                ], range: NSRange(tagname, in: source));
                
                for attr in attrs {
                    self.highlightAttr(attr: attr);
                }
            case let .EndTag(name: tagname):
                textStorage.addAttributes([
                    .foregroundColor: self.tagColor
                ], range: NSRange(token.range, in: source));
                textStorage.addAttributes([
                    .font: self.boldFont
                ], range: NSRange(tagname, in: source));
            case .Error:
                textStorage.addAttributes([
                    .foregroundColor: self.errorColor
                ], range: NSRange(token.range, in: source));
            }
            
            if tokens >= 100 {
                return false;
            }
        }
        
        return true;
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
}
#endif
