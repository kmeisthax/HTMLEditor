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

#if os(macOS)
/**
 * Fake size class variable to make AppKit happy.
 */
enum HorizontalSizeClass {
    case normal;
    case compact;
}
#endif

/**
 * Editor view for HTML files.
 * 
 * Provides both a source editor and editable preview of the web page.
 */
struct HTMLEditor: View {
    @ObservedObject var page: Page;
    
    @State var wysiwygState = WYSIWYGState.Split;
    @State var pageTitle: String? = nil;
    
    @Environment(\.dismiss) var dismiss;
    
#if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
#elseif os(macOS)
    @State var horizontalSizeClass = HorizontalSizeClass.normal;
#endif
    
    var isSplit: Bool {
        wysiwygState == .Split && horizontalSizeClass != .compact;
    }
    
    var isSource: Bool {
        wysiwygState == .Source;
    }
    
    var isWysiwyg: Bool {
        wysiwygState == .WYSIWYG || (wysiwygState == .Split && horizontalSizeClass == .compact);
    }
    
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
            
            if horizontalSizeClass != .compact {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if self.wysiwygState != .WYSIWYG {
                            self.wysiwygState = .WYSIWYG;
                        } else {
                            self.wysiwygState = .Split;
                        }
                        
                    }
                } label: {
                    if self.wysiwygState == .WYSIWYG {
                        Image(systemName: "doc.richtext.fill")
                    } else {
                        Image(systemName: "doc.richtext")
                    }
                }
            }
        }
        
        let backToolbar = ToolbarItemGroup(placement: .cancellationAction, content: {
            if horizontalSizeClass == .compact { //custom back buttons are borked on large for some reason
                Button {
                    dismiss();
                } label: {
                    Image(systemName: "folder")
                }
            }
        });
        
        GeometryReader { geo_outer in
            SourceView(text: $page.html)
                .offset(x: isWysiwyg ? geo_outer.size.width * -1.0 : 0.0)
                .frame(maxWidth: 
                        isSplit ? geo_outer.size.width / 2 : .infinity)
            WebPreview(html: $page.html, title: $pageTitle, fileURL: $page.presentedItemURL, baseURL: $page.accessURL)
                .overlay(Rectangle().frame(width: isSplit ? 1 : 0, height: nil, alignment: .leading).foregroundColor(.secondary), alignment: .leading)
                .offset(x: isSource ? geo_outer.size.width * 1.0 :
                            isSplit ? geo_outer.size.width * 0.5 : 0.0)
                .frame(maxWidth:
                        isSplit ? geo_outer.size.width / 2 :
                        isSource ? geo_outer.size.width : .infinity)
                .edgesIgnoringSafeArea(.all)
        }.toolbar {
            paneToolbar
            backToolbar
        }.pageTitlebar(for: page, customTitle: pageTitle)
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .introspectNavigationController { navigationController in
            navigationController.navigationBar.scrollEdgeAppearance = navigationController.navigationBar.standardAppearance
        }
#endif
    }
}
