import SwiftUI

/**
 * View modifier that adds a page title and subtitle to a page editor.
 *
 * The behavior of this modifier is platform-specific: on iOS, it adds a navigation toolbar
 * designed to look like a window titlebar; on macOS it actually sets the navigation title
 * and subtitle as appropriate.
 */
struct PageTitlebar: ViewModifier {
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
            ToolbarItemGroup(placement: .principal, content: {
                VStack {
                    Text(windowTitle).fontWeight(.bold)
                    if let subtitle = windowSubtitle {
                        Text(subtitle)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                }
            })
        }
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
