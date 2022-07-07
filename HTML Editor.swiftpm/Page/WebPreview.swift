import SwiftUI
import WebKit

struct WebPreview {
    @Binding var html: String;
    
    @Binding var title: String?;
    
    func makeCoordinator() -> WebPreviewCoordinator {
        WebPreviewCoordinator(owner: self, html: "")
    }
}

#if os(iOS)
extension WebPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration();
        
        config.ignoresViewportScaleLimits = true;
        
        let myWorld = WKContentWorld.world(name: "PrivateWorld");
        
        do {
            let jsurl = Bundle.main.url(forResource: "content", withExtension: "js")!;
            let js = try String.init(contentsOf: jsurl);
        
            config.userContentController = WKUserContentController();
            config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: true, in: myWorld));
            config.userContentController.add(context.coordinator, contentWorld: myWorld, name: "wysiwygChanged");
        } catch {
            print("what;")
        }
        
        let view = WKWebView(frame: .zero, configuration: config);
        
        context.coordinator.view = view;
        
        return view;
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if html != context.coordinator.htmlInSafari {
            webView.loadHTMLString(html, baseURL: nil);
            context.coordinator.htmlInSafari = html;
        }
    }
}
#endif

#if os(macOS)
extension WebPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration();
        
        let myWorld = WKContentWorld.world(name: "PrivateWorld");
        
        do {
            let jsurl = Bundle.main.url(forResource: "content", withExtension: "js")!;
            let js = try String.init(contentsOf: jsurl);
        
            config.userContentController = WKUserContentController();
            config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: true, in: myWorld));
            config.userContentController.add(context.coordinator, contentWorld: myWorld, name: "wysiwygChanged");
        } catch {
            print("what;")
        }
        
        let view = WKWebView(frame: .zero, configuration: config);
        
        context.coordinator.view = view;
        
        return view;
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if html != context.coordinator.htmlInSafari {
            webView.loadHTMLString(html, baseURL: nil);
            context.coordinator.htmlInSafari = html;
        }
    }
}
#endif

class WebPreviewCoordinator : NSObject, WKScriptMessageHandler {
    var owner: WebPreview;
    
    var htmlInSafari: String;
    
    private var _viewStorage: WKWebView? = nil;
    private var _viewKvo: NSKeyValueObservation? = nil;
    
    var view: WKWebView? {
        get {
            self._viewStorage
        }
        set {
            self._viewStorage = newValue;
            
            if let oldkvo = _viewKvo {
                oldkvo.invalidate();
            }
            
            _viewKvo = newValue?.observe(\.title, options: [.new]) { [self] _, change in
                owner.title = change.newValue!!;
            }
            
            owner.title = newValue?.title;
        }
    };
    
    init(owner: WebPreview, html: String) {
        self.owner = owner;
        self.htmlInSafari = html;
    }
    
    deinit {
        self._viewKvo?.invalidate()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.body is NSString {
            let html = message.body as! NSString as String;
            owner.html = html;
            self.htmlInSafari = html;
        }
    }
}
