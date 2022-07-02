import SwiftUI

/**
 * Snapshot of the current state of open projects (the "shoebox")
 * 
 * This is intended to be saved to disk whenever projects are created, opened,
 * or closed; and should be loaded when the application launches to restore
 * the set of open projects.
 * 
 * This does *not* include any UI state such as currently selected projects
 * or pages.
 */
struct ShoeboxState : Codable {
    var projects: [ProjectState];
    
    static var storageLoc: URL {
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("org.fantranslation.code.html-editor");
    }
    
    static var shoeboxFileLoc: URL {
        return storageLoc.appendingPathComponent("shoebox.json");
    }
    
    static func restoreFromDisk() -> Self {
        let coder = JSONDecoder();
        do {
            let state = try coder.decode(Self.self, from: Data.init(contentsOf: Self.shoeboxFileLoc));
            
            return state;
        } catch {
            if (error as NSError).code != CocoaError.fileReadNoSuchFile.rawValue {
                print("Got error message restoring shoebox state: \(error)")
            } else {
                print("State not saved yet")
            }
        }
        
        return ShoeboxState(projects: []);
    }
    
    func saveToDisk() {
        let coder = JSONEncoder();
        do {
            try FileManager.default.createDirectory(at: ShoeboxState.storageLoc, withIntermediateDirectories: true)
            let json_data = try coder.encode(self);
            
            try json_data.write(to: Self.shoeboxFileLoc);
        } catch {
            print("Got error message saving shoebox state: \(error)")
        }
    }
}
