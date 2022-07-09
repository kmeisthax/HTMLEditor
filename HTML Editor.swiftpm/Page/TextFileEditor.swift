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
            backToolbar
        }
        .pageTitlebar(for: page)
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .introspectNavigationController { navigationController in
            navigationController.navigationBar.scrollEdgeAppearance = navigationController.navigationBar.standardAppearance
        }
#endif
    }
}
