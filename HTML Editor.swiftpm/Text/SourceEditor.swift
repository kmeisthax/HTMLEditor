import SwiftUI

#if os(iOS)
class SourceEditorDelegate: NSObject, UITextViewDelegate {
    var source: Binding<String>;
    
    var outstandingSearchWorkItem: DispatchWorkItem?;
    
    var font: UIFont {
        .monospacedSystemFont(ofSize: 16, weight: .regular)
    }
    
    init(source: Binding<String>) {
        self.source = source;
    }
    
    func textViewDidChange(_ textView: UITextView) {
        source.wrappedValue = textView.text;
    }
    
    /**
     * Asynchronously search the text view for matches and highlight them.
     * 
     * This function has a match limit of about 100; if it is reached, we
     * will redispatch ourselves to continue highlighting after events are
     * processed.
     */
    func doAsyncTextSearch(searchQuery: String, textView: UITextView, lastMatch: Range<String.Index>? = nil) {
        var iterationsThisFrame = 1;
        
        if searchQuery != "" {
            var range: Range<String.Index>? = nil;
            if let lastMatch = lastMatch {
                range = lastMatch.upperBound..<source.wrappedValue.endIndex;
            }
            
            var match = self.source.wrappedValue.range(of: searchQuery, options: .init(), range: range, locale: nil);
            
            while let currentMatch = match {
                print(currentMatch);
                
                textView.textStorage.setAttributes([
                    .backgroundColor: UIColor.systemYellow,
                    .font: self.font
                ], range: NSRange(currentMatch, in: self.source.wrappedValue));
                
                iterationsThisFrame += 1;
                if iterationsThisFrame > 10 {
                    self.outstandingSearchWorkItem = DispatchWorkItem {
                        self.doAsyncTextSearch(searchQuery: searchQuery, textView: textView, lastMatch: currentMatch);
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
    
    func cancelAsyncTextSearch() {
        if let workitem = self.outstandingSearchWorkItem {
            workitem.cancel();
        }
        
        self.outstandingSearchWorkItem = nil;
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
        print("Update");
        uiView.text = self.source;
        
        context.coordinator.cancelAsyncTextSearch();
        
        print("Kicking off search for \(self.searchQuery)");
        context.coordinator.doAsyncTextSearch(searchQuery: self.searchQuery, textView: uiView);
    }
}
#endif
