import SwiftUI
import WebKit
import Combine

struct WebPreview {
    @Binding var html: String;
    
    @Binding var title: String?;
    
    @Binding var fileURL: URL?;
    @Binding var baseURL: URL?;
    
    func makeCoordinator() -> WebPreviewCoordinator {
        WebPreviewCoordinator(owner: self, html: "")
    }
}

#if os(iOS)
extension WebPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration();
        
        config.ignoresViewportScaleLimits = true;
        
        let myWorld = context.coordinator.appWorld;
        
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
        context.coordinator.sourceChanged(html: html, fileURL: fileURL, baseURL: baseURL)
    }
}
#endif

#if os(macOS)
extension WebPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration();
        
        let myWorld = context.coordinator.appWorld;
        
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
        context.coordinator.sourceChanged(html: html, fileURL: fileURL, baseURL: baseURL)
    }
}
#endif

class WebPreviewCoordinator : NSObject, WKScriptMessageHandler, ObservableObject {
    var owner: WebPreview;
    
    var htmlInSafari: String;
    var safariWasLoadedWithFilePermissions = false;
    
    private var _viewStorage: WKWebView? = nil;
    private var _viewKvo: NSKeyValueObservation? = nil;
    
    private var _sinks: [AnyCancellable] = [];
    
    var appWorld: WKContentWorld {
        WKContentWorld.world(name: "PrivateWorld")
    }
    
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
        
        super.init();
    }
    
    deinit {
        self._viewKvo?.invalidate()
    }
    
    /**
     * Process messages from Safari / the wysiwyg view that its HTML changed.
     */
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.body is NSString {
            let html = message.body as! NSString as String;
            owner.html = html;
            self.htmlInSafari = html;
        }
    }
    
    /**
     * Process messages from SwiftUI / the source view that its HTML changed.
     */
    func sourceChanged(html: String, fileURL: URL?, baseURL: URL?) {
        if html != self.htmlInSafari {
            if let fileURL = fileURL, let baseURL = baseURL {
                if !self.safariWasLoadedWithFilePermissions {
                    self._viewStorage?.loadFileURL(fileURL, allowingReadAccessTo: baseURL);
                    self.safariWasLoadedWithFilePermissions = true;
                } else {
                    self._viewStorage?.callAsyncJavaScript("quickReload(newHtml);", arguments: ["newHtml": html], in: nil, in: self.appWorld, completionHandler: nil);
                }
            } else {
                self._viewStorage?.loadHTMLString(html, baseURL: nil)
            }
            self.htmlInSafari = html;
        }
    }
}
