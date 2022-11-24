import SwiftUI

enum JSONValue {
    case Whitespace;
    case ObjectStart;
    case ObjectMember(nameString: Range<String.Index>);
    case ObjectEnd;
    case ArrayStart;
    case ArrayMember;
    case ArrayEnd;
    case StringStart;
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
    case InObject;
    case InArray;
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
        
        if self.syntaxCtx.last != .Open {
            return JSONSymbol(type: .Error, range: start);
        }
        
        let _ = self.syntaxCtx.popLast();
        self.syntaxCtx.append(.InObject);
        
        return JSONSymbol(type: .ObjectStart, range: start);
    }
    
    mutating func acceptObjectEnd() -> JSONSymbol? {
        guard let end = self.accept(substring: "}") else {
            return nil
        };
        
        if (self.syntaxCtx.last != .InObject) {
            return JSONSymbol(type: .Error, range: end);
        }
        
        let _ = self.syntaxCtx.popLast();
        
        return JSONSymbol(type: .ObjectEnd, range: end);
    }
    
    mutating func acceptArrayStart() -> JSONSymbol? {
        guard let start = self.accept(substring: "[") else {
            return nil
        };
        
        if self.syntaxCtx.last != .Open {
            return JSONSymbol(type: .Error, range: start);
        }
        
        let _ = self.syntaxCtx.popLast();
        self.syntaxCtx.append(.InArray);
        
        return JSONSymbol(type: .ObjectStart, range: start);
    }
    
    mutating func acceptArrayEnd() -> JSONSymbol? {
        guard let end = self.accept(substring: "]") else {
            return nil
        };
        
        if (self.syntaxCtx.last != .InArray) {
            return JSONSymbol(type: .Error, range: end);
        }
        
        let _ = self.syntaxCtx.popLast();
        
        return JSONSymbol(type: .ObjectEnd, range: end);
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
        } else if let ws = self.consumeWhitespace() {
            return ws;
        } else {
            return nil;
        }
    }
}
