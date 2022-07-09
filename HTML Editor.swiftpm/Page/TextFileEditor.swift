import SwiftUI
import Introspect

/**
 * Editor view for plain-jane text files.
 */
struct TextFileEditor: View {
    @ObservedObject var page: Page;
    
    @Environment(\.dismiss) var dismiss;
    
#if os(iOS)
    @EnvironmentObject var sceneDelegate: OldschoolSceneDelegate;
    @Environment(\.horizontalSizeClass) var horizontalSizeClass;
#elseif os(macOS)
    @State var horizontalSizeClass = HorizontalSizeClass.normal;
#endif
    
    var windowTitle: String {
        page.filename
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
        }
        
#if os(iOS)
        let titleToolbar = ToolbarItemGroup(placement: .principal, content: {
            VStack {
                Text(windowTitle).fontWeight(.bold)
                if let subtitle = windowSubtitle {
                    Text(subtitle)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }
        });
#endif
        
        let backToolbar = ToolbarItemGroup(placement: .cancellationAction, content: {
            if horizontalSizeClass == .compact { //custom back buttons are borked on large for some reason
                Button {
                    dismiss();
                } label: {
                    Image(systemName: "folder")
                }
            }
        });
        
        SourceView(text: $page.html)
        .toolbar {
            paneToolbar
            
#if os(iOS)
            titleToolbar
#endif
            
            backToolbar
        }
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .introspectNavigationController { navigationController in
            navigationController.navigationBar.scrollEdgeAppearance = navigationController.navigationBar.standardAppearance
        }
#endif
#if os(macOS)
        .navigationTitle(windowTitle)
        .navigationSubtitle(windowSubtitle ?? "")
#endif
    }
}
