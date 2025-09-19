import SwiftUI
import UniformTypeIdentifiers;

struct ProjectDocument : FileDocument {
    init() {
        
    }
    
    init(configuration: ReadConfiguration) throws {
        
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper()
    }
    
    static var readableContentTypes: [UTType] = [.folder];
}
