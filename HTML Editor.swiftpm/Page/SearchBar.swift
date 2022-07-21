import SwiftUI

/**
 * A search bar.
 */
struct SearchBar: View {
    #if os(iOS)
    static var HEIGHT: CGFloat = 50;
    #elseif os(macOS)
    static var HEIGHT: CGFloat = 35;
    #endif
    
    @Binding var searchQuery: String;
    @Binding var isSearching: Bool;
    
    var body: some View {
        HStack {
            TextField("Find in file...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
            Button("Next") {
                
            }
        }
        .padding([.leading, .trailing])
        .frame(height: Self.HEIGHT)
        .overlay(Rectangle().frame(width: nil, height: isSearching ? 1 : 0, alignment: .bottom).foregroundColor(.secondary), alignment: .bottom)
        .offset(y: isSearching ? 0 : Self.HEIGHT * -1.0)
        .disabled(!isSearching)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isSearching = !isSearching;
                    }
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .background(isSearching ? Color.accentColor : .clear)
                .cornerRadius(5.0)
                .foregroundColor(isSearching ? .white : .accentColor)
                .keyboardShortcut("f", modifiers: [.command])
            }
        }
    }
}