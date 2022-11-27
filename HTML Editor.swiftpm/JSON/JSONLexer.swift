import SwiftUI

enum JSONValue {
    case Whitespace;
    case ObjectStart;
    case ObjectKeySeparator;
    case ObjectEnd;
    case ArrayStart;
    case ArrayEnd;
    case NextElementSeparator;
    case StringStart(isObjectKey: bool);
    case LiteralChars;
    case Escape(unicodeScalar: UInt32);
    case StringEnd;
    case Number;
    case True;
    case False;
    case Null;
    case Error;
}

struct JSONSymbol {
    var type: JSONValue;
    var range: Range<String.Index>;
}

/**
 * A single syntax context for JSON parsing.
 * 
 * This controls which JSON symbols can be accepted at a given time.
 * For example, if we have accepted an object start, then we forbid
 * more object starts until later.
 * 
 * When a syntax context is violated, acceptors should return error
 * symbols until they can resync to a valid parsing position.
 */
enum JSONSyntaxContext {
    /**
     * All starting symbols are accepted.
     */
    case Open;
    
    /**
     * Object keys (string symbols) and ends of objects are accepted.
     */
    case InObjectKey;
    
    /**
     * Object key separators (:) are accepted.
     */
    case InObjectKeySeparator;
    
    /**
     * Object values are accepted.
     */
    case InObjectValue;
    
    /**
     * Object next-element separators (,) and ends of objects are accepted.
     */
    case InObjectNextSeparator;
    
    /**
     * Array values and ends of arrays are accepted.
     */
    case InArray;
    
    /**
     * Array next-element separator (,) and ends of objects are accepted.
     */
    case InArrayNextSeparator;
    
    /**
     * Literals, escapes, and ends of strings are accepted.
     */
    case InString;
}

struct JSONLexer : SourceLexer {
    var source: String;
    var parsingIndex: String.UnicodeScalarIndex;
    
    /**
     * Stack of parsing states since JSON is recursive.
     * 
     * For example, if we are parsing an object and then an array,
     * we want to forbid object syntax *until the array ends*.
     */
    var syntaxCtx: [JSONSyntaxContext] = [.Open];
    
    init(source: String) {
        self.source = source;
        self.parsingIndex = source.startIndex.samePosition(in: self.source.unicodeScalars)!;
    }
    
    mutating func consumeWhitespace() -> JSONSymbol? {
        guard let ws = self.consume(scalarCond: { elem in elem.value == 0x20 || elem.value == 0x0A || elem.value == 0x0D || elem.value == 0x09 }) else {
            return nil
        };
        
        return JSONSymbol(type: .Whitespace, range: ws);
    }
    
    mutating func acceptObjectStart() -> JSONSymbol? {
        guard let start = self.accept(substring: "{") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .Open:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InObjectKey);
        
        //Objects are valid array/object value types
        case .InObjectValue:
        case .InArray:
            self.syntaxCtx.append(.InObjectKey);
        
        default:
            return JSONSymbol(type: .Error, range: start);
        }
        
        
        return JSONSymbol(type: .ObjectStart, range: start);
    }
    
    mutating func acceptObjectEnd() -> JSONSymbol? {
        guard let end = self.accept(substring: "}") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .InObjectKey:
        case .InObjectNextSeparator:
            let _ = self.syntaxCtx.popLast();
        
        default:
            return JSONSymbol(type: .Error, range: end);
        }
        
        return JSONSymbol(type: .ObjectEnd, range: end);
    }
    
    mutating func acceptArrayStart() -> JSONSymbol? {
        guard let start = self.accept(substring: "[") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .Open:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InArray);
            
        // Arrays are valid object/array value types
        case .InObjectValue:
        case .InArray:
            self.syntaxCtx.append(.InArray);
        
        default:
            return JSONSymbol(type: .Error, range: start);
        }
        
        return JSONSymbol(type: .ArrayStart, range: start);
    }
    
    mutating func acceptArrayEnd() -> JSONSymbol? {
        guard let end = self.accept(substring: "]") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .InArray:
        case .InArrayNextSeparator:
            let _ = self.syntaxCtx.popLast();
            
        default:
            return JSONSymbol(type: .Error, range: end);
        }
        
        let _ = self.syntaxCtx.popLast();
        
        return JSONSymbol(type: .ArrayEnd, range: end);
    }
    
    mutating func acceptStringStartOrEnd() -> JSONSymbol? {
        guard let end = self.accept(substring: "\"") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .InArray:
        case .InObjectValue:
            self.syntaxCtx.append(.InString);
            return JSONSymbol(type: .StringStart(false), range: end);
            
        case .InObjectKey:
            self.syntaxCtx.append(.InString);
            return JSONSymbol(type: .StringStart(true), range: end);
        
        case .InString:
            self.syntaxCtx.popLast();
            return JSONSymbol(type: .StringEnd, range: end);
            
        default:
            return JSONSymbol(type: .Error, range: end);
        }
    }
    
    mutating func consumeStringCharacters() -> JSONSymbol? {
        if self.syntaxCtx.last != .InString {
            return nil;
        }
        
        //NOTE: This does not check for " or /, you must accept those first
        guard let chars = self.consume(scalarCond: { sym in 
            sym.value >= 0x20 && sym.value <= 0x10FFFF
        }) else {
            return nil
        };
        
        return JSONSymbol(type: .LiteralChars, range: chars);
    }
    
    /**
     * Accept any JSON symbol.
     * 
     * Nil indicates the end of valid symbols in the string.
     */
    mutating func acceptSymbol() -> JSONSymbol? {
        if let oStart = self.acceptObjectStart() {
            return oStart;            
        } else if let oEnd = self.acceptObjectEnd() {
            return oEnd;
        } else if let aStart = self.acceptArrayStart() {
            return aStart;            
        } else if let aEnd = self.acceptArrayEnd() {
            return aEnd;
        } else if let strBoundary = self.acceptStringStartOrEnd() {
            return strBoundary;
        } else if let ws = self.consumeWhitespace() {
            return ws;
        } else {
            return nil;
        }
    }
}
