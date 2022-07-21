import SwiftUI
import Introspect

/**
 * Select the next result of a given search query in the given text field.
 */
func selectNextResult(ofQuery: String, inString: String, selection: inout [Range<String.Index>]) {
    let searchStartIndex = selection.first?.upperBound ?? inString.startIndex;
    let searchResult = inString.range(of: ofQuery, options: .init(), range: searchStartIndex..<inString.endIndex, locale: nil);
    
    if let result = searchResult {
        selection = [result];
    } else if let result = inString.range(of: ofQuery, options: .init(), range: inString.startIndex..<inString.endIndex, locale: nil) {
        selection = [result];
    }
}

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
        
        SourceEditor(source: $page.html, selection: $selection, searchQuery: $searchQuery)
            .padding(1)
        .safeAreaInset(edge: .top) {
            SearchBar(searchQuery: $searchQuery, isSearching: $isSearching, wysiwygMode: Binding.constant(.Source), nextSource: {
                    selectNextResult(ofQuery: self.searchQuery, inString: self.page.html, selection: &self.selection)
                })
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
