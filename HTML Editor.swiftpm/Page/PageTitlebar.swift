import SwiftUI
import Introspect

/**
 * View modifier that adds a page title and subtitle to a page editor.
 *
 * The behavior of this modifier is platform-specific: on iOS, it adds a navigation toolbar
 * designed to look like a window titlebar; on macOS it actually sets the navigation title
 * and subtitle as appropriate.
 */
struct PageTitlebar: ViewModifier {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
    @Environment(\.dismiss) var dismiss;
    #endif
    
    var page: Page?;
    var pageTitle: String? = nil;
    
    var windowTitle: String {
        pageTitle ?? page?.filename ?? ""
    }
    
    var windowSubtitle: String? {
        if page?.ownership == .AppOwned {
            return "Temporary file";
        } else if let path = page?.path, path != windowTitle {
            return path;
        } else {
            return nil;
        }
    }
    
    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading, content: {
                VStack(alignment: .leading) {
                    Text(windowTitle).fontWeight(.bold)
                    if let subtitle = windowSubtitle {
                        Text(subtitle)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                }.frame(maxWidth: .infinity)
            })
            
            ToolbarItemGroup(placement: .cancellationAction, content: {
                if horizontalSizeClass == .compact { //custom back buttons are borked on large for some reason
                    Button {
                        dismiss();
                    } label: {
                        Image(systemName: "folder")
                    }
                }
            })
        }
        .navigationBarBackButtonHidden(true)
        .introspectNavigationController { navigationController in
            navigationController.navigationBar.scrollEdgeAppearance = navigationController.navigationBar.standardAppearance
        }
        .navigationTitle("")
        #elseif os(macOS)
        content
            .navigationTitle(windowTitle)
            .navigationSubtitle(windowSubtitle ?? "")
        #endif
    }
}

extension View {
    func pageTitlebar(for page: Page? = nil, customTitle: String? = nil) -> some View {
        modifier(PageTitlebar(page: page, pageTitle: customTitle))
    }
}
