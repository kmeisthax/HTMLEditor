import SwiftUI

/**
 * A search bar.
 */
struct SearchBar: View {
    #if os(iOS)
    static var HEIGHT: CGFloat = 50;
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
    #elseif os(macOS)
    static var HEIGHT: CGFloat = 35;
    #endif
    
    @Binding var searchQuery: String;
    @Binding var isSearching: Bool;
    @Binding var wysiwygMode: WYSIWYGState;
    
    var nextSource: () -> Void = {};
    var nextWysiwyg: () -> Void = {};
    
    var body: some View {
        HStack {
            if wysiwygMode != .WYSIWYG {
                Button("Next", action: nextSource)
            }
            SearchField(searchQuery: $searchQuery, placeholder: "Find in file...")
            if wysiwygMode != .Source {
                Button("Next", action: nextWysiwyg)
            }
        }
        .padding([.leading, .trailing])
        .frame(height: isSearching ? Self.HEIGHT : 0)
        .background(.bar)
        .overlay(Rectangle().frame(width: nil, height: isSearching ? 1 : 0, alignment: .bottom).foregroundColor(.secondary), alignment: .bottom)
        .disabled(!isSearching)
        .clipped()
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if self.horizontalSizeClass != .compact {
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
}
