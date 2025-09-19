import SwiftUI

struct JSONHighlighterFactory: SourceHighlighterFactory {
    func construct(source: String, textStorage: NSTextStorage) -> SourceHighlighter {
        return JSONHighlighter(source: source, textStorage: textStorage)
    }
}

struct JSONHighlighter: SourceHighlighter {
    var source: String;
    var textStorage: NSTextStorage;
    var lexer: JSONLexer;
    var lexedTokens: [JSONSymbol];
    
    init(source: String, textStorage: NSTextStorage) {
        self.source = source;
        self.textStorage = textStorage;
        self.lexer = JSONLexer(source: source);
        self.lexedTokens = []
    }
    
    mutating func highlightSource() -> Bool {
        var tokens = 0;
        
        while let token = self.lexer.acceptSymbol() {
            tokens += 1;
            
            self.lexedTokens.append(token);
            
            switch token.type {
            case .Whitespace:
                textStorage.addAttributes([
                    .foregroundColor: self.textColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
            case .ObjectStart, .ObjectEnd:
                textStorage.addAttributes([
                    .foregroundColor: self.objectColor,
                    .font: self.boldFont
                ], range: NSRange(token.range, in: source));
            case .ObjectKeySeparator:
                textStorage.addAttributes([
                    .foregroundColor: self.objectColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
            case .ArrayStart, .ArrayEnd:
                textStorage.addAttributes([
                    .foregroundColor: self.arrayColor,
                    .font: self.boldFont
                ], range: NSRange(token.range, in: source));
            case .NextElementSeparator:
                var color = self.textColor;
                switch self.lexer.syntaxCtx.last {
                case .InObjectKey, .InObjectValue, .InObjectKeySeparator, .InObjectNextSeparator:
                    color = self.objectColor
                case .InArray, .InArrayNextSeparator:
                    color = self.arrayColor
                default:
                    color = self.textColor
                }
                
                textStorage.addAttributes([
                    .foregroundColor: color,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
            case .StringStart, .StringEnd:
                textStorage.addAttributes([
                    .foregroundColor: self.stringColor,
                    .font: self.boldFont
                ], range: NSRange(token.range, in: source));
            case .LiteralChars:
                textStorage.addAttributes([
                    .foregroundColor: self.stringColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
            case .Escape:
                textStorage.addAttributes([
                    .foregroundColor: self.stringEscapeColor,
                    .font: self.boldFont
                ], range: NSRange(token.range, in: source));
            case .Number:
                textStorage.addAttributes([
                    .foregroundColor: self.numberColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
            case .True, .False, .Null:
                textStorage.addAttributes([
                    .foregroundColor: self.keywordColor,
                    .font: self.font
                ], range: NSRange(token.range, in: source));
            case .Error:
                textStorage.addAttributes([
                    .foregroundColor: self.errorColor,
                    .font: self.boldFont
                ], range: NSRange(token.range, in: source));
            }
            
            if tokens >= 100 {
                return false;
            }
        }
        
        return true;
    }
    
    mutating func sourceDidChange(newSource: String) {
        //Our lexer is stateful so we can't resync it yet
        self.lexer = JSONLexer(source: newSource);
        self.lexedTokens = [];
        self.source = newSource;
    }
}

#if os(iOS)
extension JSONHighlighter {
    var textColor: UIColor {
        .label
    }
    
    var objectColor: UIColor {
        .systemPurple
    }
    
    var arrayColor: UIColor {
        .systemIndigo
    }
    
    var stringColor: UIColor {
        .systemBlue
    }
    
    var stringEscapeColor: UIColor {
        .systemGray
    }
    
    var numberColor: UIColor {
        .systemCyan
    }
    
    var keywordColor: UIColor {
        .systemOrange
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
extension JSONHighlighter {
    var textColor: NSColor {
        .textColor
    }
    
    var objectColor: NSColor {
        .systemPurple
    }
    
    var arrayColor: NSColor {
        .systemIndigo
    }
    
    var stringColor: NSColor {
        .systemBlue
    }
    
    var stringEscapeColor: NSColor {
        .systemGray
    }
    
    var numberColor: NSColor {
        .systemCyan
    }
    
    var keywordColor: NSColor {
        .systemOrange
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
