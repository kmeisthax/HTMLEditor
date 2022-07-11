# HTML Editor

This is a currently-unbranded HTML editor for iPadOS. It uses WebKit to provide an editable preview of your HTML side-by-side with its source code.

You can run the `.swiftpm` package contained in this repo inside of Swift Playgrounds 4 on iPadOS 15.3 or later to develop, test, or just use the editor on your own iPad. No second computer or other workarounds required.

## Features

 * Side-by-side source code and direct HTML editing
 * All projects and files stored in user storage
 * Loose file support for file providers that don't allow folder access (looking at YOU, Dropbox)
 * Rudimentary file management (rename/delete) with a healthy amount of SwiftUI-related papercuts
 * Open projects listed in a quick-access "shoebox" format

## License

This program is Free Software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. We are not liable if this eats your homework. No, seriously, it's disturbingly easy to lose data with the way this app autosaves. See the GNU General Public License for more details and remember to always use a `<meta charset="utf8">` tag and make backups of everything.

We use SwiftUI Introspect as a library, which is copyright Timber Software and provided under MIT License terms.

I originally considered licensing the editor as GPLv3 to make a statement about how refreshingly unrestricted Swift Playgrounds is, but someone's gonna want to put this on their iPhone eventually and that will mean dealing with the App Store at some point

## AppKit version

An Xcode project that builds the same editor for macOS is also provided. It directly references files in the Swift package; though if you add, remove, or reorganize files in the package you will also need to update the project to match. It also requires that you manually obtain copies of the following Swift packages and place them in the following directories:

 * `vendor/SwiftUI-Introspect-0.1.4` - https://github.com/siteline/SwiftUI-Introspect.git

Users of the Swift package do not need to do this step. It only exists because Xcode projects cannot directly retrieve a package from a Git repo, unlike Swift Playgrounds, and I couldn't find a Swift package feed for it.

The Xcode project builds a proper AppKit version of the project. Using the Swift package in Xcode or Swift Playgrounds for Mac will produce a Mac Catalyst version running in the Pad idiom, which does not at all look like a Mac app.