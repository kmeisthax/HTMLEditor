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
    
    var horizontalSizeClass = PaneBreakpoint.normal;
    #endif
    
    @Binding var searchQuery: String;
    @Binding var isSearching: Bool;
    @Binding var wysiwygMode: WYSIWYGState;
    
    var prevSource: () -> Void = {};
    var nextSource: () -> Void = {};
    
    var prevWysiwyg: () -> Void = {};
    var nextWysiwyg: () -> Void = {};
    
    var body: some View {
        HStack {
            if wysiwygMode != .WYSIWYG {
                Button(action: prevSource, label: {
                    Image(systemName: "chevron.up")
                })
                Button(action: nextSource, label: {
                    Image(systemName: "chevron.down")
                })
            }
            SearchField(searchQuery: $searchQuery, placeholder: "Find in file...")
            if wysiwygMode != .Source {
                Button(action: prevWysiwyg, label: {
                    Image(systemName: "chevron.up")
                })
                Button(action: nextWysiwyg, label: {
                    Image(systemName: "chevron.down")
                })
            }
        }
        .padding([.leading, .trailing])
        .frame(height: isSearching ? Self.HEIGHT : 0)
        .background(.bar)
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
