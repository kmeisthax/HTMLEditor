import SwiftUI
import Introspect

/**
 * Editor view for plain-jane text files.
 */
struct TextFileEditor: View {
    @ObservedObject var page: Page;
    
    @State var selection: [Range<String.Index>] = [];
    
    @State var isSearching: Bool = false;
    @State var searchQuery: String = "";
    
#if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
#elseif os(macOS)
    @State var horizontalSizeClass = HorizontalSizeClass.normal;
#endif
    
    var body: some View {
#if os(iOS)
        let paneToolbarPlacement = ToolbarItemPlacement.primaryAction;
#elseif os(macOS)
        let paneToolbarPlacement = ToolbarItemPlacement.confirmationAction;
#endif
        let paneToolbar = ToolbarItemGroup(placement: paneToolbarPlacement) {
            if page.ownership == .AppOwned {
                Button {
#if os(iOS)
                    page.pickLocationForAppOwnedFile(scene: sceneDelegate.scene!);
#endif
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        
        ZStack(alignment: .top) {
            SourceEditor(source: $page.html, selection: $selection, searchQuery: $searchQuery)
                .padding(1)
                .padding([.top], isSearching ? SearchBar.HEIGHT : 1)
            SearchBar(searchQuery: $searchQuery, isSearching: $isSearching)
        }
        .toolbar {
            paneToolbar
        }
        .pageTitlebar(for: page)
#if os(iOS)
        .navigationBarBackButtonHidden(true)
#endif
    }
}
