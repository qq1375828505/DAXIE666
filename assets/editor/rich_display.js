/**
 * Copyright (C) 2015 Wasabeef
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var RDisplay = {};

RDisplay.editor = document.getElementById('editor');
RDisplay.dataSeperator = "r_e_ds";

// 文章发布时会拼接一个title给阅读器里显示：<h1 class="articleTitle" id="[id]">[title text]</h1>
// 文章详情页不需要展示，因为阅读器不执行js，所以在这里用js把它们隐藏
// 不要找dom，写一句新的style
var styleForArticleTitle = document.createElement('style');
styleForArticleTitle.innerHTML = '.articleTitle{display: none;}';
document.getElementsByTagName('head')[0].appendChild(styleForArticleTitle);

// Initializations
RDisplay.onBookToucheStart = function(ele){
    ele.classList.add('re_bookItem_Touched');
}
RDisplay.onBookToucheEnd = function(ele){
    ele.classList.remove('re_bookItem_Touched');
}
RDisplay.onBookClick = function(ele){
    var id = ele.getAttribute('data-id');
    wereadBridge.handleWithRichEditor("gotoBookDetail", {"param" : id}, "", "");
}
RDisplay.onImageClick = function(ele){
    var src = ele.getAttribute('src');
    wereadBridge.handleWithRichEditor("gotoImageDetail", {"param" : src}, "", "");
}

var reBookItems = document.querySelectorAll('.re_bookItem');
var reImgs = document.querySelectorAll('.re_img');
if(reBookItems.length > 0){
    for(var i = 0; i<reBookItems.length; i++){
        var bookItem = reBookItems[i];
        bookItem.setAttribute('ontouchstart', 'RDisplay.onBookToucheStart(this)');
        bookItem.setAttribute('ontouchend', 'RDisplay.onBookToucheEnd(this)');
        bookItem.setAttribute('ontouchcancel', 'RDisplay.onBookToucheEnd(this)');
        bookItem.setAttribute('onclick', 'RDisplay.onBookClick(this)');
    }
}
if(reImgs.length > 0){
    for(var i = 0; i<reImgs.length; i++){
        var img = reImgs[i];
        img.setAttribute('onclick', 'RDisplay.onImageClick(this)');
    }
}

// 获取当前光标的node
RDisplay.getSelectedNode = function() {
    var node = RDisplay.getSelectedBaseNode();
    if (node) { return (node.nodeName == "#text" ? node.parentNode : node); }
};

// 获取当前光标的node
RDisplay.getSelectedBaseNode = function() {
    var node, selection;
    if (window.getSelection) {
        selection = getSelection();
        node = selection.anchorNode; // 返回该选区起点所在的节点（Node）
    }
    if (!node && document.selection) {
        selection = document.selection
        var range = selection.getRangeAt ? selection.getRangeAt(0) : selection.createRange();
        node = range.commonAncestorContainer ? range.commonAncestorContainer :
        range.parentElement ? range.parentElement() : range.item(0);
    }
    return node;
};

RDisplay.setHtml = function(str){
    document.getElementById('editor').innerHTML = str;
    wereadBridge.handleWithRichEditor("setHtmlFinish",{"param" : ""}, "", "");
}

RDisplay.logDom = null;
RDisplay.log = function(str){
    if(RDisplay.logDom == null){
        RDisplay.logDom = document.createElement('div');
        RDisplay.logDom.setAttribute('style','position:absolute;top:0;right:0;font-size:12px;border:1px solid #000;color:#000;padding:3px');
        document.getElementsByTagName('body')[0].appendChild(RDisplay.logDom);
    }
    RDisplay.logDom.innerHTML = RDisplay.logDom.innerHTML + "<br/>" + str;
}