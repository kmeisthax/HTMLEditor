import SwiftUI
import WebKit

struct WebPreview: UIViewRepresentable {
    @Binding var html: String;
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration();
        
        config.ignoresViewportScaleLimits = true;
        
        return WKWebView(frame: .zero, configuration: config);
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
