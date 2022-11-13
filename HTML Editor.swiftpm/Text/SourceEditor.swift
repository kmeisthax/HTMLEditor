import SwiftUI

struct SourceEditor {
    @Binding var source: String;
    
    @Binding var selection: [Range<String.Index>];
    
    @Binding var searchQuery: String;
    
    var highlighterFactory: SourceHighlighterFactory;
    
    func makeCoordinator() -> SourceEditorDelegate {
        return SourceEditorDelegate(source: $source, selection: $selection, highlighterFactory: highlighterFactory);
    }
    
    /**
     * Reset the bindings on our coordinator.
     *
     * Occasionally this gets out of sync for some reason and this
     * hack exists to ensure the coordinator is always bound to our
     * variables.
     */
    func rebindTo(context: Context) {
        context.coordinator.source = self.$source;
        context.coordinator.selection = self.$selection;
    }
    
    func convertSwiftRangesToObjc(ranges: [Range<String.Index>], fromString: String) -> [NSValue] {
        var objcRanges: [NSValue] = [];
        
        for item in ranges {
            objcRanges.append(NSRange(item, in: fromString) as NSValue);
        }
        
        return objcRanges;
    }
}

class SourceEditorDelegate: NSObject {
    var source: Binding<String>;
    
    var selection: Binding<[Range<String.Index>]>;
    
    var lastSeenSource: String?;
    var lastSeenQuery: String?;
    var lastSeenSelection: [Range<String.Index>]?;

    var outstandingSearchWorkItem: DispatchWorkItem?;
    
    var highlighterFactory: SourceHighlighterFactory;
    var highlighter: SourceHighlighter?;
    
    init(source: Binding<String>, selection: Binding<[Range<String.Index>]>, highlighterFactory: SourceHighlighterFactory) {
        self.source = source;
        self.selection = selection;
        self.highlighterFactory = highlighterFactory;
    }
    
    var wholeStringRange: NSRange {
        let source = self.source.wrappedValue;
        
        return NSRange(source.startIndex..<source.endIndex, in: source);
    }
    
    /**
     * Asynchronously search the text view for matches and highlight them.
     *
     * This function has a match limit of about 100; if it is reached, we
     * will redispatch ourselves to continue highlighting after events are
     * processed.
     */
    func doAsyncTextSearch(searchQuery: String, textStorage: NSTextStorage, lastMatch: Range<String.Index>? = nil) {
        var iterationsThisFrame = 1;
        
        if searchQuery != "" {
            var range: Range<String.Index>? = nil;
            if let lastMatch = lastMatch {
                range = lastMatch.upperBound..<source.wrappedValue.endIndex;
            }
            
            var match = self.source.wrappedValue.range(of: searchQuery, options: .init(), range: range, locale: nil);
            
            while let currentMatch = match {
                textStorage.addAttributes([
                    .backgroundColor: self.findHighlight
                ], range: NSRange(currentMatch, in: self.source.wrappedValue));
                
                iterationsThisFrame += 1;
                if iterationsThisFrame > 10 {
                    self.outstandingSearchWorkItem = DispatchWorkItem {
                        self.doAsyncTextSearch(searchQuery: searchQuery, textStorage: textStorage, lastMatch: currentMatch);
                    }
                    
                    DispatchQueue.main.async(execute: self.outstandingSearchWorkItem!);
                    return;
                }
                
                range = currentMatch.upperBound..<source.wrappedValue.endIndex;
                match = self.source.wrappedValue.range(of: searchQuery, options: .init(), range: range, locale: nil);
            }
        }
        
        self.outstandingSearchWorkItem = nil;
    }
    
    /**
     * Cancel an in-progress text search and remove any highlighting on text.
     */
    func cancelAsyncTextSearch(textStorage: NSTextStorage) {
        if let workitem = self.outstandingSearchWorkItem {
            workitem.cancel();
        }
        
        textStorage.addAttributes([.backgroundColor: self.noHighlight], range: self.wholeStringRange);
        
        self.outstandingSearchWorkItem = nil;
    }
    
    /**
     * Convert a string selection range from NSTextView format to Swift format.
     */
    func convertObjcStringRangesToSwift(range: [NSValue], fromString: String) -> [Range<String.Index>] {
        var swiftRanges : [Range<String.Index>] = [];
        
        for selection in range {
            if let swiftRange = Range(selection as! NSRange, in: fromString) {
                swiftRanges.append(swiftRange);
            } else {
                print("Selection range not representable in Swift: \(selection)");
            }
        }
        
        return swiftRanges
    }
    
    func startAsyncHighlight(textStorage: NSTextStorage) {
        let alreadyHighlighting = self.highlighter != nil;
        
        if !alreadyHighlighting {
            self.resetAsyncHighlight(textStorage: textStorage);
        } else {
            self.highlighter!.sourceDidChange(newSource: self.source.wrappedValue);
            self.doAsyncHighlight();
        }
    }
    
    func resetAsyncHighlight(textStorage: NSTextStorage) {
        self.highlighter = self.highlighterFactory.construct(source: self.source.wrappedValue, textStorage: textStorage);
        
        self.doAsyncHighlight();
    }
    
    func doAsyncHighlight() {
        DispatchQueue.main.async(execute: DispatchWorkItem {
            if var highlighter = self.highlighter {
                if !highlighter.highlightSource() {
                    self.highlighter = highlighter;
                    return self.doAsyncHighlight();
                }
            }
        });
    }
}

#if os(iOS)
extension SourceEditorDelegate: UITextViewDelegate {
    var font: UIFont {
        .monospacedSystemFont(ofSize: 16, weight: .regular)
    }
    
    var textColor: UIColor {
        .label
    }
    
    var findHighlight: UIColor {
        .systemYellow
    }
    
    var noHighlight: UIColor {
        .clear
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.source.wrappedValue = textView.text;
        self.lastSeenSource = textView.text;
        
        self.startAsyncHighlight(textStorage: textView.textStorage)
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        let swiftSelection = Range(textView.selectedRange, in: textView.text);
        guard let swiftSelection = swiftSelection else {
            print("Selection failure, \(textView.selectedRange) is invalid");
            return;
        }
        
        if [swiftSelection] != self.selection.wrappedValue {
            self.lastSeenSelection = [swiftSelection];
            self.selection.wrappedValue = [swiftSelection];
        }
    }
}

/**
 * Custom UITextField adapter that allows search, highlighted text, etc
 */
extension SourceEditor: UIViewRepresentable {
    func makeUIView(context: Context) -> UITextView {
        self.rebindTo(context: context);
        
        let view = UITextView();
        
        view.delegate = context.coordinator;
        view.autocorrectionType = .no;
        view.smartQuotesType = .no;
        view.autocapitalizationType = .none;
        view.allowsEditingTextAttributes = false;
        view.font = context.coordinator.font;
        view.contentInsetAdjustmentBehavior = .always;
        
        return view;
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        self.rebindTo(context: context);
        
        let didChange = context.coordinator.lastSeenSource != self.source;
        
        if didChange {
            context.coordinator.lastSeenSource = self.source;
            
            uiView.text = self.source;
            
            context.coordinator.resetAsyncHighlight(textStorage: uiView.textStorage);
        }
        
        if context.coordinator.lastSeenQuery != self.searchQuery || didChange {
            context.coordinator.lastSeenQuery = self.searchQuery;
            
            context.coordinator.cancelAsyncTextSearch(textStorage: uiView.textStorage);
            context.coordinator.doAsyncTextSearch(searchQuery: self.searchQuery, textStorage: uiView.textStorage);
        }
        
        if context.coordinator.lastSeenSelection != self.selection {
            if let selection = self.selection.first {
                uiView.selectedRange = NSRange(selection, in: self.source);
            } else {
                //'No selection' is not a valid state, so ignore it.
            }
        }
    }
}
#elseif os(macOS)
extension SourceEditorDelegate: NSTextViewDelegate {
    var font: NSFont {
        .monospacedSystemFont(ofSize: 16, weight: .regular)
    }
    
    var findHighlight: NSColor {
        .systemYellow
    }
    
    var noHighlight: NSColor {
        .clear
    }
    
    var textColor: NSColor {
        .textColor
    }
    
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return };
        
        self.source.wrappedValue = textView.string;
        self.lastSeenSource = textView.string;
        
        self.startAsyncHighlight(textStorage: textView.textStorage);
    }
    
    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return };
        
        let swiftSelection = self.convertObjcStringRangesToSwift(range: textView.selectedRanges, fromString: textView.string);
        
        if swiftSelection != self.selection.wrappedValue || self.selection.count == 0 {
            DispatchQueue.main.async {
                self.lastSeenSelection = swiftSelection;
                self.selection.wrappedValue = swiftSelection;
            }
        }
    }
}

/**
 * Custom NSTextField adapter that allows search, highlighted text, etc
 */
extension SourceEditor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let scrollview = NSTextView.scrollableTextView();
        let textview = scrollview.documentView as! NSTextView;
        
        textview.delegate = context.coordinator;
        
        textview.autoresizingMask = [.height, .width];
        textview.font = context.coordinator.font;
        
        textview.isAutomaticSpellingCorrectionEnabled = false;
        textview.isAutomaticQuoteSubstitutionEnabled = false;
        
        return scrollview;
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        self.rebindTo(context: context);
        
        let textview = nsView.documentView as! NSTextView;
        
        if let textStorage = textview.textStorage {
            let didChange = context.coordinator.lastSeenSource != self.source;
            
            if didChange {
                context.coordinator.lastSeenSource = self.source;
                
                let selection = textview.selectedRanges;
                
                textview.selectedRanges = selection;
                //TODO: Wait shouldn't this set the text
                
                context.coordinator.resetAsyncHighlight(textStorage: textStorage);
            }
            
            if context.coordinator.lastSeenQuery != self.searchQuery || didChange {
                context.coordinator.lastSeenQuery = self.searchQuery;
                
                context.coordinator.cancelAsyncTextSearch(textStorage: textStorage);
                context.coordinator.doAsyncTextSearch(searchQuery: self.searchQuery, textStorage: textStorage)
            }
            
            if context.coordinator.lastSeenSelection != self.selection {
                if self.selection.count == 0 {
                    //Empty selection is illegal so we treat it as do nothing.
                } else {
                    textview.selectedRanges = self.convertSwiftRangesToObjc(ranges: self.selection, fromString: self.source);
                }
            }
        }
    }
}
#endif
