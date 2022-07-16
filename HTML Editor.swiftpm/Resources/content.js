"use strict";

var html = document.querySelector("html");

html.contentEditable = true;
html.oninput = function() {
    var updated = new XMLSerializer().serializeToString(document);
    
    window.webkit.messageHandlers.wysiwygChanged.postMessage(updated);
}

/**
 * Replace the contents of the page with a new document without
 * triggering a full browser reload.
 */
function quickReload(newHtml) {
    html.innerHTML = newHtml;
    
    var newdoc = new DOMParser().parseFromString(newHtml, "text/html");
    console.log(newdoc);
    
    if (newdoc.documentElement.nodeName == "HTML") {
        var old_attributes = html.attributes, old_attribute_list = [];
        
        for (var i = 0; i < old_attributes.length; i += 1) {
            old_attribute_list.push(old_attributes[i].name);
        }
        
        for (var i = 0; i < old_attribute_list.length; i += 1) {
            html.removeAttribute(old_attribute_list[i]);
        }
        
        var new_attributes = newdoc.documentElement.attributes;
        
        for (var i = 0; i < new_attributes.length; i += 1) {
            html.setAttribute(new_attributes[i].name, new_attributes[i].value);
        }
    }
}

/**
 * Change the title of the document, then trigger user input.
 */
function changeTitle(newTitle) {
    if (document.title != newTitle) {
        document.title = newTitle;
        html.oninput();
    }
}
