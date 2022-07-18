import SwiftUI

/**
 * Programmer-friendly text editor pane.
 */
struct SourcePane : View {
    @Binding var text: String;
    
    @State var isSearching: Bool = false;
    @State var searchQuery: String = "";
    
    var body: some View {
        ZStack(alignment: .top) {
            SourceEditor(source: $text, searchQuery: $searchQuery)
                .padding(1)
                .padding([.top], isSearching ? 60 : 1)
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Toggle(isOn: $isSearching) {
                            Image(systemName: "magnifyingglass")
                        }.keyboardShortcut("f", modifiers: [.command])
                    }
                }
            HStack {
                TextField("Find in file...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
            }
                .padding()
                .frame(height: 60)
                .overlay(Rectangle().frame(width: nil, height: isSearching ? 1 : 0, alignment: .bottom).foregroundColor(.secondary), alignment: .bottom)
                .offset(y: isSearching ? 0 : -60)
                .disabled(!isSearching)
        }
    }
}
