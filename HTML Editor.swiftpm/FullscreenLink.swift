import SwiftUI

/**
 * A wrapper around `.fullScreenCover` that stores the open/closed state.
 * 
 * Useful for ForEach et all.
 * 
 * Contains a view hierarchy inside of a floating layer that is opened
 * when the associated label view is pressed.
 */
struct FullscreenLink<Content, LabelContent>: View where Content: View, LabelContent: View {
    @State var isPresented = false;
    
    /**
     * Content builder function.
     * 
     * Accepts a closure which must be called when the inner view
     * wants to dismiss itself.
     */
    var content: (@escaping () -> Void) -> Content;
    
    /**
     * Label builder function.
     */
    var label: () -> LabelContent;
    
    var body: some View {
        Button {
            isPresented = true;
        } label: {
            label()
        }.fullScreenCover(isPresented: $isPresented, onDismiss: {
            isPresented = false;
        }) {
            content({
                isPresented = false;
            })
        }
    }
}
