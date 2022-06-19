"use strict";

var html = document.querySelector("html");

html.contentEditable = true;
html.oninput = function() {
    var updated = new XMLSerializer().serializeToString(document);
    
    window.webkit.messageHandlers.wysiwygChanged.postMessage(updated);
}
