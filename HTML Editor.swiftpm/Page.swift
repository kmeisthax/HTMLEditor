import SwiftUI
import Foundation
import Combine

/**
 * Viewmodel class for individual HTML files in a project.
 * 
 * Intended to be owned by a Project viewmodel. Also adopts NSFilePresenter
 * to allow file updates (which apparently even Swift Playgrounds itself
 * doesn't do?)
 * 
 * View code should not create pages directly; views should ask their
 * associated Project to create a Page and then access it from there.
 */
class Page : NSObject, ObservableObject, Identifiable, NSFilePresenter {
    var id: UUID;
    
    @Published var presentedItemURL: URL?;
    
    var filename: String {
        if let url = presentedItemURL {
            return url.lastPathComponent
        } else {
            return "Untitled"
        }
    };
    
    lazy var presentedItemOperationQueue: OperationQueue = OperationQueue.main;
    
    @Published var html: String = "<!DOCTYPE html>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">";
    
    var c: [AnyCancellable] = [];
    
    override init() {
        id = UUID.init()
        
        super.init()
        
        $html.sink(receiveValue: { [weak self] html in
            if let url = self?.presentedItemURL {
                let coordinator = NSFileCoordinator.init(filePresenter: self);
                
                print(url);
                
                coordinator.coordinate(with: [.writingIntent(with: url)], queue: self!.presentedItemOperationQueue) { error in
                    if let error = error {
                        print (error);
                    }
                    
                    self!.doActualSave(url: url, html: html);
                }
            }
        }).store(in: &c);
    }
    
    class func fromSecurityScopedUrl(url: URL) -> Page {
        let page = Page();
        page.presentedItemURL = url;
        
        let coordinator = NSFileCoordinator.init(filePresenter: page);
        
        coordinator.coordinate(with: [.readingIntent(with: url)], queue: page.presentedItemOperationQueue) { error in
            //TODO: Error handling.
            if let error = error {
                print (error);
            }
            
            page.presentedItemDidChange();
        };
        
        print("Opened");
        
        return page;
    }
    
    func presentedItemDidChange() {
        if let url = self.presentedItemURL {
            if !CFURLStartAccessingSecurityScopedResource(url as CFURL) {
                //panic! at the disco
                print("Cannot access URL")
            }
            
            do {
                self.html = try String(contentsOf: url);
            } catch {
                //panic?!
                print("Error reading URL")
            }
            
            CFURLStopAccessingSecurityScopedResource(url as CFURL);
        } else {
            print("No URL")
        }
    }
    
    private func doActualSave(url: URL, html: String) {
        if !CFURLStartAccessingSecurityScopedResource(url as CFURL) {
            //panic! at the disco
            print("Cannot access URL")
        }
        
        do {
            print("About to save");
            try html.write(to: url, atomically: true, encoding: .utf8);
            print("Saved");
        } catch {
            //panic?!
            print("Error writing URL")
        }
        
        CFURLStopAccessingSecurityScopedResource(url as CFURL);
    }
}
