import SwiftUI

/**
 * Programmer-friendly text editor
 */
struct SourceView : View {
    @Binding var text: String;
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body).monospaced())
            .disableAutocorrection(true)
            .padding(1)
            .introspectTextView { editor in
#if os(iOS)
                editor.smartQuotesType = UITextSmartQuotesType.no;
                editor.autocapitalizationType = .none;
#elseif os(macOS)
                editor.isAutomaticQuoteSubstitutionEnabled = false;
#endif
            }
    }
}
