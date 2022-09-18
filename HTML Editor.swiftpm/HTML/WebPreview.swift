import SwiftUI
import WebKit
import Combine

struct WebPreview {
    @Binding var html: String;
    
    @Binding var title: String?;
    
    @Binding var fileURL: URL?;
    @Binding var baseURL: URL?;
    
    @Binding var searchQuery: String;
    
    // Dummy binding to trigger a search
    @Binding var forwardSearch: UInt32;
    @Binding var backwardsSearch: UInt32;
    
    func makeCoordinator() -> WebPreviewCoordinator {
        WebPreviewCoordinator(owner: self, html: "")
    }
    
    func makePlatformView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration();
        
        #if os(iOS)
        config.ignoresViewportScaleLimits = true;
        #endif
        
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
    
    func updatePlatformView(_ webView: WKWebView, context: Context) {
        // We have to distinguish between two kinds of updates here:
        //
        // 1. Updates intended to cause a reload (e.g. html changing)
        // 2. Updates intended to make Safari do our HTML edits for us
        //
        // If HTML changes we can't also trigger any property updates,
        // and if we're updating properties we have to ignore our own
        // HTML lest we overwrite our own changes.
        if (html != context.coordinator.htmlInSafari) {
            context.coordinator.sourceChanged(html: html, fileURL: fileURL, baseURL: baseURL);
        } else if let title = self.title {
            context.coordinator.changeTitle(newTitle: title);
        }
        
        if (forwardSearch != context.coordinator.lastForwardsSearch) {
            context.coordinator.lastForwardsSearch = forwardSearch;
            webView.find(self.searchQuery, configuration: .init()) { _ in 
                
            };
        }
        
        if (backwardsSearch != context.coordinator.lastBackwardsSearch) {
            context.coordinator.lastBackwardsSearch = backwardsSearch;
            
            let backwards = WKFindConfiguration.init();
            backwards.backwards = true;
            
            webView.find(self.searchQuery, configuration: backwards) { _ in 
                
            };
        }
    }
}

#if os(iOS)
extension WebPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        return self.makePlatformView(context: context);
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        self.updatePlatformView(webView, context: context);
    }
}
#elseif os(macOS)
extension WebPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        return self.makePlatformView(context: context);
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        self.updatePlatformView(webView, context: context);
    }
}
#endif

class WebPreviewCoordinator : NSObject, WKScriptMessageHandler, ObservableObject {
    var owner: WebPreview;
    
    var htmlInSafari: String;
    var safariWasLoadedWithFilePermissions = false;
    
    var lastBackwardsSearch: UInt32 = 0;
    var lastForwardsSearch: UInt32 = 0;
    
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
    
    /**
     * Change the title of the current document.
     * 
     * This will also trigger an autosave through the standard mechanism. 
     */
    func changeTitle(newTitle: String) {
        self._viewStorage?.callAsyncJavaScript("changeTitle(newTitle);", arguments: ["newTitle": newTitle], in: nil, in: self.appWorld, completionHandler: nil);
    }
}
