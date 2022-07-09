import SwiftUI

struct ImagePreview: View {
    @ObservedObject var page: Page;
    
    var body: some View {
        AsyncImage(url: page.presentedItemURL) { image in
            image.resizable().aspectRatio(contentMode: .fit)
        } placeholder: {
            ProgressView()
        }.pageTitlebar(for: page)
    }
}
