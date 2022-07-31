import SwiftUI

/**
 * A search bar.
 */
struct SearchBar: View, BreakpointCalculator {
    #if os(iOS)
    static var HEIGHT: CGFloat = 50;
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
    #elseif os(macOS)
    static var HEIGHT: CGFloat = 35;
    #endif
    
    @Binding var searchQuery: String;
    @Binding var isSearching: Bool;
    @Binding var wysiwygState: WYSIWYGState;
    
    var prevSource: () -> Void = {};
    var nextSource: () -> Void = {};
    
    var prevWysiwyg: () -> Void = {};
    var nextWysiwyg: () -> Void = {};
    
    var body: some View {
        GeometryReader { geo in
            let breakpoint = self.paneBreakpoint(geo.size);
            
            let isSource = wysiwygState == .Source;
            let isWysiwyg = wysiwygState == .WYSIWYG || (wysiwygState == .Split && self.paneBreakpoint(geo.size) == .compact);
            
            HStack {
                if !isWysiwyg {
                    Button(action: prevSource, label: {
                        Image(systemName: "chevron.up")
                    })
                    Button(action: nextSource, label: {
                        Image(systemName: "chevron.down")
                    })
                }
                SearchField(searchQuery: $searchQuery, placeholder: "Find in file...")
                if !isSource {
                    Button(action: prevWysiwyg, label: {
                        Image(systemName: "chevron.up")
                    })
                    Button(action: nextWysiwyg, label: {
                        Image(systemName: "chevron.down")
                    })
                }
            }
            .padding([.leading, .trailing])
            #if os(iOS)
            .padding([.vertical], -3)
            #else
            .padding([.vertical], 7)
            #endif
            .disabled(!isSearching)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    if breakpoint != .compact {
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
        .frame(height: isSearching ? Self.HEIGHT : 0)
        .background(.bar)
        .clipped()
    }
}
