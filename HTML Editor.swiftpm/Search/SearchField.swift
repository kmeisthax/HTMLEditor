import SwiftUI

struct SearchField {
    @Binding var searchQuery: String;
    var placeholder: String;
}

class SearchFieldCoordinator: NSObject {
    var field: SearchField;
    
    init(field: SearchField) {
        self.field = field;
    }
}

#if os(iOS)
extension SearchFieldCoordinator: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        field.searchQuery = searchText;
    }
}

extension SearchField: UIViewRepresentable {
    func makeCoordinator() -> SearchFieldCoordinator {
        return SearchFieldCoordinator(field: self);
    }
    
    func makeUIView(context: Context) -> UISearchBar {
        let bar = UISearchBar();
        
        bar.delegate = context.coordinator;
        bar.searchBarStyle = .minimal;
        
        return bar;
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = self.searchQuery;
        uiView.placeholder = placeholder;
    }
}
#endif
