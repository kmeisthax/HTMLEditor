import SwiftUI

class SourceEditorDelegate: NSObject {
    var source: Binding<String>;
    
    var lastSeenSource: String?;
    var lastSeenQuery: String?;
    
    var outstandingSearchWorkItem: DispatchWorkItem?;
    
    init(source: Binding<String>) {
        self.source = source;
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
}

#if os(iOS)
extension SourceEditorDelegate: UITextViewDelegate {
    var font: UIFont {
        .monospacedSystemFont(ofSize: 16, weight: .regular)
    }
    
    var findHighlight: UIColor {
        .systemYellow
    }
    
    var noHighlight: UIColor {
        .clear
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.source.wrappedValue = textView.text;
    }
}

/**
 * Custom UITextField adapter that allows search, highlighted text, etc
 */
struct SourceEditor: UIViewRepresentable {
    @Binding var source: String;
    @Binding var searchQuery: String;
    
    func makeCoordinator() -> SourceEditorDelegate {
        return SourceEditorDelegate(source: $source);
    }
    
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView();
        
        view.delegate = context.coordinator;
        view.autocorrectionType = .no;
        view.smartQuotesType = .no;
        view.autocapitalizationType = .none;
        view.allowsEditingTextAttributes = false;
        view.font = context.coordinator.font;
        
        return view;
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // Careless hack around SourceEditorDelegate not getting the correct binding the first time
        context.coordinator.source = self.$source;
        
        let didChange = context.coordinator.lastSeenSource != self.source;
        
        if didChange {
            context.coordinator.lastSeenSource = self.source;
            
            let selection = uiView.selectedRange;
            
            uiView.text = self.source;
            
            uiView.selectedRange = selection;
        }
        
        if context.coordinator.lastSeenQuery != self.searchQuery || didChange {
            context.coordinator.lastSeenQuery = self.searchQuery;
            
            context.coordinator.cancelAsyncTextSearch(textStorage: uiView.textStorage);
            context.coordinator.doAsyncTextSearch(searchQuery: self.searchQuery, textStorage: uiView.textStorage);
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
    
    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return };
        
        self.source.wrappedValue = textView.string;
    }
}

/**
 * Custom NSTextField adapter that allows search, highlighted text, etc
 */
struct SourceEditor: NSViewRepresentable {
    @Binding var source: String;
    @Binding var searchQuery: String;
    
    func makeCoordinator() -> SourceEditorDelegate {
        return SourceEditorDelegate(source: self.$source);
    }
    
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
        let textview = nsView.documentView as! NSTextView;
        
        // Careless hack around SourceEditorDelegate not getting the correct binding the first time
        context.coordinator.source = self.$source;
        
        if let textStorage = textview.textStorage {
            let didChange = context.coordinator.lastSeenSource != self.source;
            
            if didChange {
                context.coordinator.lastSeenSource = self.source;
                
                let selection = textview.selectedRanges;
                
                textStorage.setAttributedString(NSAttributedString(string: self.source, attributes: [.font: context.coordinator.font]));
                
                textview.selectedRanges = selection;
            }
            
            if context.coordinator.lastSeenQuery != self.searchQuery || didChange {
                context.coordinator.lastSeenQuery = self.searchQuery;
                
                context.coordinator.cancelAsyncTextSearch(textStorage: textStorage);
                context.coordinator.doAsyncTextSearch(searchQuery: self.searchQuery, textStorage: textStorage)
            }
        }
    }
}
#endif
