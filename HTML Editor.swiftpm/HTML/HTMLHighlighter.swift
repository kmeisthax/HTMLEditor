import SwiftUI

struct HTMLHighlighter: SourceHighlighter {
    func highlightAttr(source: String, textStorage: NSTextStorage, attr: Attribute) {
        textStorage.addAttributes([
            .foregroundColor: self.attributeNameColor
        ], range: NSRange(attr.name, in: source));
        
        if let value = attr.value {
            textStorage.addAttributes([
                .foregroundColor: self.attributeValueColor
            ], range: NSRange(value, in: source));
        }
    }
    
    func highlightSource(source: String, textStorage: NSTextStorage) {
        var lexer = HTMLLexer(source: source);
        
        while let token = lexer.acceptSymbol() {
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
                    self.highlightAttr(source: source, textStorage: textStorage, attr: attr);
                }
            case let .StartTag(name: tagname, attributes: attrs, selfClosing: _):
                textStorage.addAttributes([
                    .foregroundColor: self.tagColor
                ], range: NSRange(token.range, in: source));
                textStorage.addAttributes([
                    .font: self.boldFont
                ], range: NSRange(tagname, in: source));
                
                for attr in attrs {
                    self.highlightAttr(source: source, textStorage: textStorage, attr: attr);
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
        }
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
