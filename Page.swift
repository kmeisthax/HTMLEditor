import SwiftUI
import Foundation

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
    
    override init() {
        id = UUID.init()
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
}
