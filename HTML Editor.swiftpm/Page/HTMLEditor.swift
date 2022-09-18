import SwiftUI
import Introspect

/**
 * Which set of editors are currently visible.
 */
enum WYSIWYGState {
    /**
     * Only the editable preview is shown.
     */
    case WYSIWYG;
    
    /**
     * Only the document source is shown.
     */
    case Source;
    
    /**
     * Both preview and source are shown, side-by-side.
     *
     * This mode is unavailable on compact views and instead becomes the WYSIWYG state.
     */
    case Split;
}

/**
 * Editor view for HTML files.
 * 
 * Provides both a source editor and editable preview of the web page.
 */
struct HTMLEditor: View, BreakpointCalculator {
    @ObservedObject var page: Page;
    
    @Binding var wysiwygState : WYSIWYGState;
    @State var fakeWysiwygState : WYSIWYGState;
    
    @State var selection: [Range<String.Index>] = [];
    
    @State var isSearching: Bool = false;
    @State var searchQuery: String = "";
    
    @State var pageTitle: String? = nil;
    
    @State var lastForwardWebSearch: UInt32 = 0;
    @State var lastBackwardWebSearch: UInt32 = 0;
    
#if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
#elseif os(macOS)
#endif
    
    var windowTitle: String {
        pageTitle ?? page.filename
    }
    
    var windowSubtitle: String? {
        if page.ownership == .AppOwned {
            return "Temporary file";
        } else if let path = page.path, path != windowTitle {
            return path;
        } else {
            return nil;
        }
    }
    
    var body: some View {
        #if os(iOS)
        let paneToolbarPlacement = ToolbarItemPlacement.primaryAction;
        #elseif os(macOS)
        let paneToolbarPlacement = ToolbarItemPlacement.confirmationAction;
        #endif
        
        GeometryReader { geo_outer in
            let isSplit = wysiwygState == .Split && self.paneBreakpoint(geo_outer.size) != .compact;
            let isSource = wysiwygState == .Source;
            let isWysiwyg = wysiwygState == .WYSIWYG || (wysiwygState == .Split && self.paneBreakpoint(geo_outer.size) == .compact);
            
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
                
                if self.paneBreakpoint(geo_outer.size) != .compact {
                    Picker(selection: self.$fakeWysiwygState, label: Text("View")) {
                        Image(systemName: "curlybraces.square").tag(WYSIWYGState.Source)
                        Image(systemName: "rectangle.split.2x1").tag(WYSIWYGState.Split)
                        Image(systemName: "doc.richtext").tag(WYSIWYGState.WYSIWYG)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: self.fakeWysiwygState) { newState in
                        if self.fakeWysiwygState != self.wysiwygState {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                self.wysiwygState = self.fakeWysiwygState;
                            }
                        }
                    }
                    .onChange(of: self.wysiwygState) { newState in
                        if self.wysiwygState != self.fakeWysiwygState {
                            self.fakeWysiwygState = self.wysiwygState;
                        }
                    }
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if self.wysiwygState != .Source {
                                self.wysiwygState = .Source;
                            } else {
                                self.wysiwygState = .Split;
                            }
                        }
                    } label: {
                        if self.wysiwygState == .Source {
                            Image(systemName: "curlybraces.square.fill")
                        } else {
                            Image(systemName: "curlybraces.square")
                        }
                    }
                }
            }
            
            SourceEditor(source: $page.html, selection: $selection, searchQuery: $searchQuery, highlighter: HTMLHighlighter())
                .padding(1)
                .offset(x: isWysiwyg ? geo_outer.size.width * -1.0 : 0.0)
                .frame(maxWidth:
                        isSplit ? geo_outer.size.width / 2 : .infinity)
                .edgesIgnoringSafeArea(.bottom)
                .toolbar {
                    paneToolbar
                }
            WebPreview(html: $page.html, title: $pageTitle, fileURL: $page.presentedItemURL, baseURL: $page.accessURL, searchQuery: $searchQuery, forwardSearch: $lastForwardWebSearch, backwardsSearch: $lastBackwardWebSearch)
                .overlay(Rectangle().frame(width: isSplit ? 1 : 0, height: nil, alignment: .leading).foregroundColor(.secondary), alignment: .leading)
                .offset(x: isSource ? geo_outer.size.width * 1.0 :
                            isSplit ? geo_outer.size.width * 0.5 : 0.0)
                .frame(maxWidth:
                        isSplit ? geo_outer.size.width / 2 :
                        isSource ? geo_outer.size.width : .infinity)
                .edgesIgnoringSafeArea(.all)
        }.safeAreaInset(edge: .bottom) {
            SearchBar(searchQuery: $searchQuery, isSearching: $isSearching, wysiwygState: $wysiwygState, 
                      prevSource: {
                selectPrevResult(ofQuery: self.searchQuery, inString: self.page.html, selection: &self.selection)},
                      nextSource: {
                selectNextResult(ofQuery: self.searchQuery, inString: self.page.html, selection: &self.selection)
            },
                      prevWysiwyg: {
                self.lastBackwardWebSearch += 1;
            },
                      nextWysiwyg: {
                self.lastForwardWebSearch += 1;
            })
        }.pageTitlebarMenu(for: page, customTitle: $pageTitle) {
            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isSearching = !isSearching;
                }
            } label: {
                Label("Find in page...", systemImage: "doc.text.magnifyingglass")
            }
        }
    }
}
