//
//  ErrorView.swift
//  HTML Editor for AppKit
//
//  Created by David W. Wendt JR on 7/9/22.
//

import SwiftUI

/**
 * View that displays an error to the user for files we can't open.
 */
struct ErrorView: View {
    var error: String;
    
    var body: some View {
        ZStack {
            #if os(iOS)
            Color(UIColor.secondarySystemBackground)
                .edgesIgnoringSafeArea(.all)
            #endif
            VStack {
                Image(systemName: "questionmark.folder").font(.system(size: 180, weight: .medium))
                Text(error)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
