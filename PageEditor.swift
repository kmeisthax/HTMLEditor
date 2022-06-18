import SwiftUI

struct PageEditor: View {
    @Binding var html: String
    
    var body: some View {
        HStack {
            TextEditor(text: $html)
            WebPreview(html: $html)
        }
    }
}
