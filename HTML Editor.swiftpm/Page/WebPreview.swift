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
    
    /**
     * Event source for when we want to force a reload from disk.
     *
     * This is not an actual variable, it just exists so that we can abuse
     * the Combine machinery to get a proper debounce.
     *
     * The underlying idea here is that we have several different UI
     * constraints that require us to reload WebKit in different ways
     * to avoid losing data in certain circumstances.
     *
     * First: the "source of truth" for what the current state of the document
     * is changes based on what view is currently in focus, if another app
     * is changing the file, and so on. NSFilePresenter handles the latter
     * case but we still have to keep WebKit and the text field in sync at
     * all times. If we don't, then the user will type things in one field and
     * see things disappear in the other.
     *
     * Second: the set of methods WKWebView provides for reloading the
     * document are either "reload from disk with subresources" or "reload
     * from string without subresources". We can work around this by having
     * JavaScript do the reloading for us, but we don't actually have a "fresh"
     * document and we can't change properties on <html> without parsing
     * it ourselves.
     *
     * Third: we throttle saves to disk. This means that reloads from disk will
     * be delayed from the user's typing. This is wrong, we want the user to
     * be able to type and see their changes show up in the web preview
     * immediately.
     *
     * So, we have to cheat a little: we do the JavaScript fake reload on every
     * keystroke, so the user can see their changes show up. Then, once the
     * changes have hit the disk, we do a real reload so that, if they touched
     * <html>, those changes are reflected in WebKit and won't be lost if
     * they start typing in the WYSIWYG editor.
     *
     * The actual debounce is in init(), but its timer is deliberately set to be
     * slightly longer than the throttle timer in Page so that we don't miss our
     * reload chance. This is still a gamble as Page does a coordinated write
     * and it could take too long for things to actually hit the disk. But the risk
     * is still low.
     */
    @Published var reload: Void = ();
    
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
        
        self.$reload.debounce(for: .seconds(1.1), scheduler: RunLoop.main).sink {
            self.sourceChanged(html: self.owner.html, fileURL: self.owner.fileURL, baseURL: self.owner.baseURL, forceReloadFromDisk: true)
        }.store(in: &_sinks)
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
     *
     * The forceReloadFromDisk parameter will cause a reload from the file URL given,
     * regardless of if it's necessary or not.
     */
    func sourceChanged(html: String, fileURL: URL?, baseURL: URL?, forceReloadFromDisk: Bool = false) {
        if html != self.htmlInSafari || forceReloadFromDisk {
            if let fileURL = fileURL, let baseURL = baseURL {
                if !self.safariWasLoadedWithFilePermissions || forceReloadFromDisk {
                    self._viewStorage?.loadFileURL(fileURL, allowingReadAccessTo: baseURL);
                    self.safariWasLoadedWithFilePermissions = true;
                } else {
                    self._viewStorage?.callAsyncJavaScript("quickReload(newHtml);", arguments: ["newHtml": html], in: nil, in: self.appWorld, completionHandler: nil);
                    self.reload = ();
                }
            } else {
                self._viewStorage?.loadHTMLString(html, baseURL: nil)
            }
            self.htmlInSafari = html;
        }
    }
}
