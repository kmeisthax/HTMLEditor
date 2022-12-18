import SwiftUI

enum JSONValue {
    case Whitespace;
    case ObjectStart;
    case ObjectKeySeparator;
    case ObjectEnd;
    case ArrayStart;
    case ArrayEnd;
    case NextElementSeparator;
    case StringStart(isObjectKey: Bool);
    case LiteralChars;
    case Escape(unicodeScalar: UInt32);
    case StringEnd;
    case Number(parsed: Float64);
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
        case .InObjectValue, .InArray:
            self.syntaxCtx.append(.InObjectKey);
        
        default:
            return JSONSymbol(type: .Error, range: start);
        }
        
        return JSONSymbol(type: .ObjectStart, range: start);
    }
    
    mutating func acceptObjectKeySeparator() -> JSONSymbol? {
        guard let start = self.accept(substring: ":") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .InObjectKeySeparator:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InObjectValue);
            
        default:
            return JSONSymbol(type: .Error, range: start);
        }
        
        return JSONSymbol(type: .ObjectKeySeparator, range: start);
    }
    
    mutating func acceptNextElementSeparator() -> JSONSymbol? {
        guard let start = self.accept(substring: ",") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .InObjectNextSeparator:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InObjectKey);
        
        case .InArrayNextSeparator:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InArray);
            
        default:
            return JSONSymbol(type: .Error, range: start);
        }
        
        return JSONSymbol(type: .NextElementSeparator, range: start);
    }
    
    mutating func acceptObjectEnd() -> JSONSymbol? {
        guard let end = self.accept(substring: "}") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .InObjectKey, .InObjectNextSeparator:
            let _ = self.syntaxCtx.popLast();
        default:
            let _ = self.syntaxCtx.popLast();
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
            let _ = self.syntaxCtx.popLast();
            
            self.syntaxCtx.append(.InObjectNextSeparator);
            self.syntaxCtx.append(.InArray);
        case .InArray:
            let _ = self.syntaxCtx.popLast();
            
            self.syntaxCtx.append(.InArrayNextSeparator);
            self.syntaxCtx.append(.InArray);
        
        default:
            return JSONSymbol(type: .Error, range: start);
        }
        
        return JSONSymbol(type: .ArrayStart, range: start);
    }
    
    mutating func acceptArrayEnd() -> JSONSymbol? {
        if self.syntaxCtx.last == .InString {
            return nil;
        }
        
        guard let end = self.accept(substring: "]") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .InArray, .InArrayNextSeparator:
            let _ = self.syntaxCtx.popLast();
        default:
            let _ = self.syntaxCtx.popLast();
            return JSONSymbol(type: .Error, range: end);
        }
        
        return JSONSymbol(type: .ArrayEnd, range: end);
    }
    
    mutating func acceptStringStartOrEnd() -> JSONSymbol? {
        guard let end = self.accept(substring: "\"") else {
            return nil
        };
        
        switch self.syntaxCtx.last {
        case .InObjectValue:
            let _ = self.syntaxCtx.popLast();
            
            self.syntaxCtx.append(.InObjectNextSeparator);
            self.syntaxCtx.append(.InString);
            return JSONSymbol(type: .StringStart(isObjectKey: false), range: end);
            
        case .InArray:
            let _ = self.syntaxCtx.popLast();
            
            self.syntaxCtx.append(.InArrayNextSeparator);
            self.syntaxCtx.append(.InString);
            return JSONSymbol(type: .StringStart(isObjectKey: false), range: end);
            
        case .InObjectKey:
            let _ = self.syntaxCtx.popLast();
            
            self.syntaxCtx.append(.InObjectKeySeparator);
            self.syntaxCtx.append(.InString);
            return JSONSymbol(type: .StringStart(isObjectKey: true), range: end);
        
        case .InString:
            let _ = self.syntaxCtx.popLast();
            return JSONSymbol(type: .StringEnd, range: end);
            
        default:
            return JSONSymbol(type: .Error, range: end);
        }
    }
    
    mutating func acceptStringEscape() -> JSONSymbol? {
        guard let start = self.accept(substring: "\\") else {
            return nil
        };
        
        let typeEnd = self.source.index(start.upperBound, offsetBy: 1);
        let type = self.source[start.upperBound..<typeEnd];
        
        self.parsingIndex = typeEnd;
        
        switch type {
        case "\"":
            return JSONSymbol(type: .Escape(unicodeScalar: 0x22), range: start.lowerBound..<typeEnd)
        case "\\":
            return JSONSymbol(type: .Escape(unicodeScalar: 0x5C), range: start.lowerBound..<typeEnd)
        case "/":
            return JSONSymbol(type: .Escape(unicodeScalar: 0x2F), range: start.lowerBound..<typeEnd)
        case "b", "B":
            return JSONSymbol(type: .Escape(unicodeScalar: 0x08), range: start.lowerBound..<typeEnd)
        case "f", "F":
            return JSONSymbol(type: .Escape(unicodeScalar: 0x0C), range: start.lowerBound..<typeEnd)
        case "n", "N":
            return JSONSymbol(type: .Escape(unicodeScalar: 0x0A), range: start.lowerBound..<typeEnd)
        case "r", "R":
            return JSONSymbol(type: .Escape(unicodeScalar: 0x0D), range: start.lowerBound..<typeEnd)
        case "t", "T":
            return JSONSymbol(type: .Escape(unicodeScalar: 0x09), range: start.lowerBound..<typeEnd)
        case "u", "U":
            let unicodeEnd = self.source.index(typeEnd, offsetBy: 4);
            guard let unicode = UInt32(self.source[typeEnd..<unicodeEnd]) else {
                return JSONSymbol(type: .Error, range: start.lowerBound..<unicodeEnd)
            };
            
            self.parsingIndex = unicodeEnd;
            return JSONSymbol(type: .Escape(unicodeScalar: UInt32(unicode)), range: start.lowerBound..<unicodeEnd)
        default:
            return JSONSymbol(type: .Error, range: start.lowerBound..<typeEnd)
        }
    }
    
    mutating func consumeStringCharacters() -> JSONSymbol? {
        //NOTE: This does not check for " or /, you must accept those first
        guard let chars = self.consume(scalarCond: { sym in 
            return sym.value >= 0x20 && sym.value <= 0x10FFFF && sym.value != 0x5C && sym.value != 0x22;
        }) else {
            return nil
        };
        
        return JSONSymbol(type: .LiteralChars, range: chars);
    }
    
    mutating func acceptTrue() -> JSONSymbol? {
        guard let chars = self.accept(substring: "true") else {
            return nil;
        }
        
        switch self.syntaxCtx.last {
        case .InArray:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InArrayNextSeparator);
        case .InObjectValue:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InObjectNextSeparator);
        default:
            return JSONSymbol(type: .Error, range: chars);
        }
        
        return JSONSymbol(type: .True, range: chars);
    }
    
    mutating func acceptFalse() -> JSONSymbol? {
        guard let chars = self.accept(substring: "false") else {
            return nil;
        }
        
        switch self.syntaxCtx.last {
        case .InArray:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InArrayNextSeparator);
        case .InObjectValue:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InObjectNextSeparator);
        default:
            return JSONSymbol(type: .Error, range: chars);
        }
        
        return JSONSymbol(type: .False, range: chars);
    }
    
    mutating func acceptNull() -> JSONSymbol? {
        guard let chars = self.accept(substring: "null") else {
            return nil;
        }
        
        switch self.syntaxCtx.last {
        case .InArray:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InArrayNextSeparator);
        case .InObjectValue:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InObjectNextSeparator);
        default:
            return JSONSymbol(type: .Error, range: chars);
        }
        
        return JSONSymbol(type: .Null, range: chars);
    }
    
    mutating func consumeDigits(allowLeadingZero: Bool) -> Range<String.Index>? {
        var first = true;
        
        return self.consume(scalarCond: { elem in
            let isAllowedZero = (allowLeadingZero || !first) && elem.value == 0x30;
            let isNonZeroDigit = elem.value >= 0x31 || elem.value < 0x3A;
            
            first = false;
            
            return isAllowedZero || isNonZeroDigit;
        });
    }
    
    mutating func acceptNumber() -> JSONSymbol? {
        let checkpoint = self.parsingIndex;
        let sign = (self.accept(substring: "-") != nil) ? -1.0 : 1.0;
        let isZero = self.accept(substring: "0") != nil;
        var wholepart = 0.0;
        if !isZero {
            guard let digits = self.consumeDigits(allowLeadingZero: false) else {
                self.parsingIndex = checkpoint;
                return nil;
            };
            
            for digit in self.source[digits] {
                wholepart *= 10;
                wholepart += Float64(digit.wholeNumberValue!);
            }
        }
        
        let hasFraction = self.accept(substring: ".") != nil;
        var fracpart = 0.0;
        if hasFraction {
            guard let digits = self.consumeDigits(allowLeadingZero: true) else {
                //TODO: Error recovery
                return JSONSymbol(type: .Error, range: checkpoint..<self.parsingIndex);
            }
            
            var slot = 0.1;
            for digit in self.source[digits] {
                fracpart += Float64(digit.wholeNumberValue!) * slot;
                slot /= 10;
            }
        }
        
        wholepart += fracpart;
        
        let hasExponent = self.accept(substring: "e", caseSensitive: false) != nil;
        var expPart = 0.0;
        if hasExponent {
            let hasPositive = self.accept(substring: "+") != nil;
            let hasNegative = self.accept(substring: "-") != nil;
            
            if (hasPositive && hasNegative) {
                //TODO: Error recovery
                return JSONSymbol(type: .Error, range: checkpoint..<self.parsingIndex);
            }
            
            guard let digits = self.consumeDigits(allowLeadingZero: true) else {
                //TODO: Error recovery
                return JSONSymbol(type: .Error, range: checkpoint..<self.parsingIndex);
            }
            
            let sign = hasNegative ? -1.0 : 1.0;
            
            for digit in self.source[digits] {
                expPart *= 10;
                expPart += Float64(digit.wholeNumberValue!);
            }
            
            expPart *= sign;
        }
        
        let value = (wholepart + fracpart) * sign * pow(10.0, expPart);
        let chars = checkpoint..<self.parsingIndex;
        
        switch self.syntaxCtx.last {
        case .InArray:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InArrayNextSeparator);
        case .InObjectValue:
            let _ = self.syntaxCtx.popLast();
            self.syntaxCtx.append(.InObjectNextSeparator);
        default:
            return JSONSymbol(type: .Error, range: chars);
        }
        
        return JSONSymbol(type: .Number(parsed: value), range: chars);
    }
    
    /**
     * Accept any JSON symbol.
     * 
     * Nil indicates the end of valid symbols in the string.
     */
    mutating func acceptSymbol() -> JSONSymbol? {
        if self.syntaxCtx.last == .InString {
            if let strBoundary = self.acceptStringStartOrEnd() {
                return strBoundary;
            } else if let strEscape = self.acceptStringEscape() {
                return strEscape;
            } else if let strLit = self.consumeStringCharacters() {
                return strLit;
            } else {
                return nil;
            }
        } else {
            if let oStart = self.acceptObjectStart() {
                return oStart;
            } else if let oKSep = self.acceptObjectKeySeparator() {
                return oKSep;
            } else if let oEnd = self.acceptObjectEnd() {
                return oEnd;
            } else if let aStart = self.acceptArrayStart() {
                return aStart;
            } else if let aEnd = self.acceptArrayEnd() {
                return aEnd;
            } else if let strBoundary = self.acceptStringStartOrEnd() {
                return strBoundary;
            } else if let bTrue = self.acceptTrue() {
                return bTrue;
            } else if let bFalse = self.acceptFalse() {
                return bFalse;
            } else if let vNull = self.acceptNull() {
                return vNull;
            } else if let num = self.acceptNumber() {
                return num;
            } else if let ws = self.consumeWhitespace() {
                return ws;
            } else {
                return nil;
            }
        }
    }
}
