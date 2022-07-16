import SwiftUI
import Introspect

/**
 * Detail view for any and all files in a project.
 */
struct PageEditor: View {
    @ObservedObject var page: Page;
    
    @Binding var wysiwygState: WYSIWYGState;
    
    var body: some View {
        if page.type == .html {
            HTMLEditor(page: page, wysiwygState: $wysiwygState, fakeWysiwygState: wysiwygState)
        } else if page.type == .text || page.type?.isSubtype(of: .text) ?? false {
            TextFileEditor(page: page)
        } else if page.type?.isSubtype(of: .image) ?? false {
            ImagePreview(page: page)
        } else if let desc = page.type?.localizedDescription {
            ErrorView(error: "Unknown file type: \(desc)").pageTitlebar(for: page)
        } else {
            ErrorView(error: "Unknown file type").pageTitlebar(for: page)
        }
    }
}
