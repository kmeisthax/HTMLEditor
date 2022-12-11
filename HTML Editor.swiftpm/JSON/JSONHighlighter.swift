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
            case .LiteralChars, .Escape:
                textStorage.addAttributes([
                    .foregroundColor: self.stringColor,
                    .font: self.font
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
                self.lexer = JSONLexer(source: newSource);
                self.lexer.advance(to: lexPosition);
                
                self.source = newSource;
                return;
            }
        }
        
        //Fail case: could not resync lexer to new string or no common prefix
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
        .systemBlue
    }
    
    var arrayColor: UIColor {
        .systemOrange
    }
    
    var stringColor: UIColor {
        .systemMint
    }
    
    var numberColor: UIColor {
        .systemGray
    }
    
    var keywordColor: UIColor {
        .systemPink
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
        .label
    }
    
    var objectColor: NSColor {
        .systemBlue
    }
    
    var arrayColor: NSColor {
        .systemOrange
    }
    
    var stringColor: NSColor {
        .systemMint
    }
    
    var numberColor: NSColor {
        .systemGray
    }
    
    var keywordColor: NSColor {
        .systemPink
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
