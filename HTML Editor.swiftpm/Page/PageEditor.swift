import SwiftUI
import Introspect

/**
 * Detail view for any and all files in a project.
 */
struct PageEditor: View {
    @ObservedObject var page: Page;
    
    var body: some View {
        if page.type == .html {
            HTMLEditor(page: page)
        } else if page.type == .text || page.type?.isSubtype(of: .text) ?? false {
            TextFileEditor(page: page)
        }
    }
}
