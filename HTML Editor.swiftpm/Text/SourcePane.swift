import SwiftUI

/**
 * Programmer-friendly text editor pane.
 */
struct SourcePane : View {
    @Binding var text: String;
    
    @State var isSearching: Bool = false;
    @State var searchQuery: String = "";
    
    var body: some View {
        #if os(iOS)
        GeometryReader { geo in
            SourceEditor(source: $text, searchQuery: $searchQuery)
                .padding(1)
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Toggle(isOn: $isSearching) {
                            Image(systemName: "magnifyingglass")
                        }.keyboardShortcut("f", modifiers: [.command])
                    }
                }.frame(maxHeight: isSearching ? geo.size.height - 60 : .infinity)
            HStack {
                TextField("Find in file...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            .overlay(Rectangle().frame(width: nil, height: isSearching ? 1 : 0, alignment: .top).foregroundColor(.secondary), alignment: .top)
            .offset(y: isSearching ? geo.size.height - 60 : geo.size.height)
            .frame(height: 60)
        }
        #elseif os(macOS)
        TextEditor(text: $text)
            .font(.system(.body).monospaced())
            .disableAutocorrection(true)
            .padding(1)
            .introspectTextView { editor in
                editor.isAutomaticQuoteSubstitutionEnabled = false;
            }
        #endif
    }
}
