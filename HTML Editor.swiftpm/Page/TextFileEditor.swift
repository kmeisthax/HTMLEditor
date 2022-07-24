import SwiftUI
import Introspect

/**
 * Select the previous result of a given search query in the given text field.
 */
func selectPrevResult(ofQuery: String, inString: String, selection: inout [Range<String.Index>]) {
    let searchEndIndex = selection.first?.lowerBound ?? inString.endIndex;
    let searchResult = inString.range(of: ofQuery, options: .backwards, range: inString.startIndex..<searchEndIndex, locale: nil);
    
    if let result = searchResult {
        selection = [result];
    } else if let result = inString.range(of: ofQuery, options: .backwards, range: inString.startIndex..<inString.endIndex, locale: nil) {
        selection = [result];
    }
}

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
    @State var horizontalSizeClass = PaneBreakpoint.normal;
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
            .edgesIgnoringSafeArea(.bottom)
        .safeAreaInset(edge: .bottom) {
            SearchBar(searchQuery: $searchQuery, isSearching: $isSearching, wysiwygMode: Binding.constant(.Source),
                      prevSource: {
                selectPrevResult(ofQuery: self.searchQuery, inString: self.page.html, selection: &self.selection)},
                      nextSource: {
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
