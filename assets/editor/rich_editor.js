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


var KEY_LEFT = 37,
    KEY_RIGHT = 39,
    KEY_AT_CODE = 50,
    KEY_HASH_CODE = 51,
    KEY_BACKSPACE = 'U+0008',
    KEY_BACKSPACE_CODE = 8,
    KEY_AT_CHAR = '@',
    KEY_HASH_CHAR = '#';

var RE = {};

var MutationObserver = window.MutationObserver ||
        window.WebKitMutationObserver ||
        window.MozMutationObserver;
var mutationObserverSupport = !!MutationObserver;

RE.currentSelection = {
    'startContainer': 0,
    'startOffset': 0,
    'endContainer': 0,
    'endOffset': 0
};
RE.defaultHtml = '<p><br></p>';

var articleTitle = document.querySelector('#titleInput');
var articleTitleInput = document.querySelector('#titleInput_text');

RE.editor = document.getElementById('editor');
RE.fakeEditor = document.getElementById('fakeEditor');
RE.currentEditingLink; //当前光标前的link
RE.currentEditingAfterLink; //当前光标后的link
RE.currentEditingImage; //当前光标前的img
RE.lastInsertLink; // 最后一次插入的link
RE.dataSeperator = 'r_e_ds';
RE.faceSplitStrLeft = 'l_f_s';
RE.faceSplitStrRight = 'r_f_s';

RE.authorWords = document.getElementById('authorWords');
RE.avatar = document.getElementById('avatar');

RE.setAuthorWordsShow = function(status) {
    RE.authorWords.style.display = (status == 1 ? "" : "none")
}
RE.setAvatar = function(avatarSrc) {
    RE.avatar.setAttribute('src', avatarSrc);
}

RE.setAuthorWords = function(words) {
    document.getElementById('words').innerHTML = words;
}

RE.setAuthorName = function(name) {
    document.getElementById('authorName').innerHTML = name;
}

RE.setContentEditable = function(editable) {
    RE.editor.setAttribute('contenteditable', 'false');
    RE.editor.setAttribute('contentEditable', 'false');
}

RE.logDom = null;
RE.log = function(str){
    if(RE.logDom == null){
        RE.logDom = document.createElement('div');
        RE.logDom.setAttribute('style','position:absolute;top:0;right:0;font-size:12px;border:1px solid #000;color:#000;padding:3px');
        document.getElementsByTagName('body')[0].appendChild(RE.logDom);
    }
    RE.logDom.innerHTML = str;
}

RE.init = function() {
    RE.editor.classList.add('re_Android');
    RE.editor.classList.add('re_Write');
    // 统一段落标签为p
    document.execCommand('defaultParagraphSeparator', false, 'p');
}

RE.isHTMLEmpty = function () {
    var html = RE.getHtml();
    if(html.indexOf('<img') !== -1) {
        return false
    }

    if(typeof(RE.editor.innerText) == 'undefined') {
        return true;
    }
    return RE.editor.innerText.trim().length == 0;

}

RE.insertAfter = function(newElement,targetElement){
    if(targetElement.parentNode){
      var parent = targetElement.parentNode;
      if(targetElement.nextSibling){
          parent.insertBefore(newElement, targetElement.nextSibling);
      }else{
          parent.appendChild(newElement);
      }
    }
}
RE.isSpecifiedTag = function(node, tagName){
    if(!node){
      return false;
    }
    if(tagName instanceof Array){
        return tagName.indexOf(node.nodeName.toLowerCase())<0?false:true;
    }
    return node.nodeName.toLowerCase() == tagName;
}
RE.isInTag = function(node, targetTagName) {
    // 判断光标是否在指定标签内并返回相应的node
    var result = null;
    if(targetTagName instanceof Array){
        for(var i = 0; i<targetTagName.length; i++){
            var tagName = targetTagName[i];
            result = checkIf(node, tagName);
            if(result){
                break;
            }
        }
    }else{
        var result = checkIf(node, targetTagName);
    }
    return result;
    function checkIf(node, targetTagName){
        if (RE.isSpecifiedTag(node, targetTagName)) {
            // 坑：
            // 要从自己开始匹配，不能直接从parentElement开始匹配。
            // 例如当点击引用的时候，没输入内容之前取消引用，这个时候无法取消引用，因为传进来的note和targetTagName一样
            return {
                'is': true,
                'tagNode': node
            }
        } else {
            var p = node.parentNode;
            while (p && (!RE.isSpecifiedTag(p, targetTagName) && !RE.isSpecifiedTag(p, 'body'))) {
                p = p.parentElement
            }
            if (RE.isSpecifiedTag(p, targetTagName)) {
                return {
                    'is': true,
                    'tagNode': p
                }
            } else {
                return false;
            }
        }
    }
}

RE.containsTag = function(node, targetTagName) {
       var result = false;
       if(targetTagName instanceof Array){
           for(var i = 0; i<targetTagName.length; i++){
               var tagName = targetTagName[i];
               result = checkIf(node, tagName);
               if(result){
                   break;
               }
           }
       }else{
           var result = checkIf(node, targetTagName);
       }
       return result;
       function checkIf(node, targetTagName){
           if (RE.isSpecifiedTag(node, targetTagName)) {
               // 坑：
               // 要从自己开始匹配，不能直接从parentElement开始匹配。
               // 例如当点击引用的时候，没输入内容之前取消引用，这个时候无法取消引用，因为传进来的note和targetTagName一样
               return true;
           } else {
               var p = node.childNodes;

               for(i=0; i<p.length;i++){
                   if(RE.containsTag(p[i],targetTagName)){
                      return true;
                   }
               }
               return false;
           }
       }

}

RE.nodeIndexInParent = function(node) {
    return Array.prototype.indexOf.call(node.parentNode.childNodes, node);
}

/** add by gongyong 5.31 **/
RE.getParentNode = function(node) {
    if(node && node.nodeType == 3) {
        return node.parentNode || null;
    }
    return node;
}

// Initializations
RE.editor.addEventListener('input', function(e){

    wereadBridge.handleWithRichEditor('onArticleTextChange',{'param' : RE.getArticleText()}, '', '');
    wereadBridge.handleWithRichEditor('onTextChange',{'param' : RE.getText()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlChange',{'param' : RE.getHtml()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlForEpubChange',{'param' : RE.getHtmlForEpub()}, '', '');
    wereadBridge.handleWithRichEditor('onTextContentLengthChange',{'param' : RE.getArticleText().replace(/(^\s*)|(\s*$)/g,"").length}, '', '');
    wereadBridge.confirmDispatchMessage();



  /** add by gongyong 5.31 **/
  var node = RE.getSelectedBaseNode();
  var node2 = RE.getParentNode(node);
  if(node && node2) {
      var coords = RE.getCoords(node2);
        var scrollTop = window.document.body.scrollTop;
        var clientHeight = document.documentElement.clientHeight;
        var preSpanHeight = RE.preSpanHeight;
        var offsetTop = RE.editor.offsetTop;

        var caretY = coords.top + preSpanHeight;

        if(scrollTop > caretY - offsetTop) {
          window.scrollTo(0, caretY - offsetTop - preSpanHeight);
        }

        if(scrollTop  < caretY - clientHeight) {
          window.scrollTo(0, caretY - clientHeight);
        }
  }



    // 编辑器首行包个p，这里用js在设置一次是因为
    // 单纯在html写一个p是可以被删除的
    if(RE.getHtml().length == 0){
        RE.setHeading('p');
        RE.editor.classList.add('re_placeholder');
    }else{
        RE.editor.classList.remove('re_placeholder');
        if (RE.editor.lastChild) {
            var lastChild = RE.editor.lastChild;
            console.log(lastChild.tagName);
            if (lastChild.tagName && (lastChild.tagName.toLowerCase() == 'p')
             && (lastChild.innerHTML == '<br />' || lastChild.innerHTML == '<br>' || lastChild.innerHTML.length == 0)) {
            } else {
                var newEmptyLine = RE.generateEmptyPara();
                RE.editor.appendChild(newEmptyLine);
            }
        }
    }
    RE.addImgMarginForSiblingText();
});
RE.addImgMarginForSiblingText = function(){
    // 输入时判断当前node（文字或段落）有没有包含img，有的话再按需要加上margin
    var sel = window.getSelection(),
        currentNode = sel.focusNode,
        targetContainer;
    if(currentNode.nodeType == 3){
        targetContainer = currentNode.parentNode;
    }else if((currentNode.nodeType == 1) && (currentNode.nodeName.toLowerCase() != 'br')){
        targetContainer = currentNode;
    }
    if(targetContainer.querySelectorAll('.re_img').length > 0){
        var tempDom = document.createElement('p'),
            imgs = targetContainer.querySelectorAll('.re_img');
        for(var i=0; i<imgs.length; i++){
            var img = imgs[i];
            tempDom.innerHTML = img.parentNode.innerHTML; //做这一步是为了保证拿到正确的sibling，避免移动光标导致文字node被切割成单独一个字符的node
            var tempImg = tempDom.querySelector('.re_img');
            if(tempImg.previousSibling){
                img.classList.add('re_img_MarginTop');
            }else{
                img.classList.remove('re_img_MarginTop');
            }
            if(tempImg.nextSibling){
                img.classList.add('re_img_MarginBottom');
            }else{
                img.classList.remove('re_img_MarginBottom');
            }
            // 这些class在发布的时候需要去掉
        }
    }
}

document.addEventListener('selectionchange', function(e) {
    if(RE.isFocus()){
      RE.backuprange();
    }
    RE.contentChanged(e);
});

// 将编辑框滚动到正确的位置
RE.calculateEditorHeightWithCaretPosition = function() {
    var currentSelectionY = RE.getCaretYPosition();//拿到的位置是光标底部位置
    var scrollOffsetY = window.document.body.scrollTop;
    var containerHeight = document.documentElement.clientHeight;
    var newPosotion = window.pageYOffset;
    //这里滚到光标头部位置
    if (currentSelectionY - RE.preSpanHeight < scrollOffsetY) {
        // 光标所在位置被滚动到顶部
        newPosotion = currentSelectionY - RE.preSpanHeight;
    } else if (currentSelectionY >= (scrollOffsetY + containerHeight)) {
        // 光标位置在界面下面看不到
        //这里滚到光标底部位置
        newPosotion = currentSelectionY - containerHeight;
    }

    window.scrollTo(0, newPosotion);
}

// 获取当前光标的位置
RE.preSpanHeight = 0;
RE.getCaretYPosition = function() {
    if (RE.isFocus()) {
        var selection = window.getSelection();
        var range = selection.getRangeAt(0);
    } else {
        var selection = RE.currentSelection;
        var range = document.createRange();
        if((RE.currentSelection.startContainer == 0) || (RE.currentSelection.endContainer == 0)){
            range.setStart(RE.editor, 0);
            range.setEnd(RE.editor, 0);
        }else{
            range.setStart(RE.currentSelection.startContainer, RE.currentSelection.startOffset);
            range.setEnd(RE.currentSelection.endContainer, RE.currentSelection.endOffset);
        }
    }
    var spanNode = document.createElement('span');
    spanNode.innerHTML = '<br>';
    spanNode.style.cssText = 'display: inline-block; vertical-align: top;';
    // collapse的意思是位到这个range的头部还是尾部，如果参数是true则定位到头部，如果是false则定位到尾部
    range.collapse(false);
    range.insertNode(spanNode);
    // 插入一个临时的标签然后计算这个标签的位置，就是光标的位置。操作完之后再把这个标签remove掉
    var position = RE.getCoords(spanNode);
    RE.preSpanHeight = position.height;
    var topPosition = position.top + RE.preSpanHeight;
    spanNode.parentNode.removeChild(spanNode);
    return topPosition;
}

RE.getCoords = function(elem) {
    var box = elem.getBoundingClientRect();

    var body = document.body;
    var docEl = document.documentElement;

    var scrollTop = window.pageYOffset || docEl.scrollTop || body.scrollTop;
    var scrollLeft = window.pageXOffset || docEl.scrollLeft || body.scrollLeft;

    var clientTop = docEl.clientTop || body.clientTop || 0;
    var clientLeft = docEl.clientLeft || body.clientLeft || 0;

    var top  = box.top +  scrollTop - clientTop;
    var left = box.left + scrollLeft - clientLeft;

    return { top: Math.round(top), left: Math.round(left), height: box.height, width: box.width };
}

// 设置样式class，切换日夜模式
RE.setEditorTheme = function(theme){
    if(theme == 'night'){
        RE.editor.classList.add('re_Night');
    }else{
        RE.editor.classList.remove('re_Night');
    }
}

// 获取当前光标的node，需要
// 1：当输入框只有纯文本时，返回当前文本node
// 2：当文本处于link内，则返回文本所在的link
// so：按目前需求，判断当前node是否在link内，是则返回link，否则返回文本。需要正多层嵌套如a>b>i的时候是否有问题，这个在contentChanged里的isInLink里面判断
RE.getSelectedNode = function() {
    var node = RE.getSelectedBaseNode();
    if (node) {
        var inLink = RE.isInTag(node, 'a'),
            isLink = RE.isSpecifiedTag(node, 'a');

        return isLink? node : (inLink.is?inLink.tagNode : node);

    }
};

// 获取当前光标的node
RE.getSelectedBaseNode = function() {
    if (!RE.isFocus()) {
        return RE.currentSelection.endContainer;
    }
    var node, selection;
    if (window.getSelection) {
        selection = getSelection();
        if(selection.focusNode != selection.anchorNode){
          // 跨node的选择，返回起始node的共同父元素
          var range = selection.getRangeAt(0);
          node = range.commonAncestorContainer;
        }else{
          node = selection.anchorNode; // 返回该选区起点所在的节点（Node）
        }
    }
    return node;
};

/** add by shaojianyu **/
RE.getSelectedFirstParentNode = function(tagName){
   var resultNode;
   if(document.getSelection()){
      if(document.getSelection().rangeCount>0){
          var currentNode = document.getSelection().getRangeAt(0).startContainer;
          do{
             if(currentNode.tagName &&
                 (currentNode.tagName.toLowerCase() == tagName)){
                 resultNode = currentNode;
                 break;
             }
             currentNode = currentNode.parentNode;
          }
          while(currentNode);
      }
   }
   return resultNode;
}

RE.getSelectionHtml = function() {
    var html = "";
    if (typeof window.getSelection != "undefined") {
        var sel = window.getSelection();
        if (sel.rangeCount) {
            var container = document.createElement("div");
            for (var i = 0, len = sel.rangeCount; i < len; ++i) {
                container.appendChild(sel.getRangeAt(i).cloneContents());
            }
            html = container.innerHTML;
        }
    } else if (typeof document.selection != "undefined") {
        if (document.selection.type == "Text") {
            html = document.selection.createRange().htmlText;
        }
    }
    return html;
}

RE.setHtml = function(contents) {

    RE.editor.innerHTML = contents;
    RE.focus();
    RE.contentChanged({});

    wereadBridge.handleWithRichEditor('onTextChange',{'param' : RE.getText()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlChange',{'param' : RE.getHtml()}, '', '');
    wereadBridge.confirmDispatchMessage();

}

RE.setArticleContent = function(title,contents){

    articleTitleInput.value = title;
    RE.editor.innerHTML = contents;
    RE.contentChanged({});

    wereadBridge.handleWithRichEditor('onArticleTitleChange',{'param' : RE.getArticleTitle()}, '', '');
    wereadBridge.handleWithRichEditor('onArticleTextChange',{'param' : RE.getArticleText()}, '', '');
    wereadBridge.handleWithRichEditor('onTextChange',{'param' : RE.getText()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlChange',{'param' : RE.getHtml()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlSet',{'param' : RE.getHtml()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlForEpubChange',{'param' : RE.getHtmlForEpub()}, '', '')
    wereadBridge.handleWithRichEditor('onTextContentLengthChange',{'param' : RE.getArticleText().replace(/(^\s*)|(\s*$)/g,"").length}, '', '');
    wereadBridge.confirmDispatchMessage();

    RE.calculateEditorHeightWithCaretPosition();
}

RE.emptyContent = function() {
    RE.editor.innerHTML = '';
    articleTitleInput.value = '';
}

RE.emptyEditor = function() {
    RE.currentSelection = {
          'startContainer': 0,
          'startOffset': 0,
          'endContainer': 0,
          'endOffset': 0
          };
    RE.editor.innerHTML = RE.defaultHtml;
    articleTitleInput.value = '';
    RE.contentChanged({});
}

RE.getHtml = function() {
    return RE.editor.innerHTML;
}

RE.getHtmlForEpub = function() {

    var html = RE.editor.innerHTML.replace('re_img_MarginBottom', '')
                                  .replace('re_img_MarginTop', '');
    return correctArticle(html, {pInQuote: true}); // 发布时处理blockquote里面的段落
}

RE.getArticleText = function() {
    var tempDom = document.createElement('div');
    // 过滤掉插入的书dom里的文字，这里需要过滤掉零宽连字符，不然牛逼的ios里面会出现乱码
    tempDom.innerHTML = RE.editor.innerHTML.replace(new RegExp('\u200D', 'g'), '')
                                            .replace('<br>', '')
                                            .replace('<br />', '');
    // getArticleText时将插入的书籍和图片转化成 [书籍] [图片]
    var books = tempDom.querySelectorAll('.re_bookItem'),
        imgs = tempDom.querySelectorAll('.re_img');
    if(books.length > 0){
        for(var i=0; i<books.length; i++){
            var bookDom = books[i],
                bookTextNode = document.createTextNode('[书籍]');
            bookDom.parentNode.insertBefore(bookTextNode, bookDom);
            bookDom.parentNode.removeChild(bookDom);
        }
    }
    if(imgs.length > 0){
        for(var i=0; i<imgs.length; i++){
            var imgDom = imgs[i],
                //imgTextNode = document.createTextNode('[图片]');
                imgTextNode = document.createTextNode('');
            imgDom.parentNode.insertBefore(imgTextNode, imgDom);
            imgDom.parentNode.removeChild(imgDom);
        }
    }
    return tempDom.innerText;
}

RE.getText = function() {
    return RE.editor.innerText;
}

RE.setPadding = function(left, top, right, bottom) {
    RE.editor.style.paddingLeft = left;
    RE.editor.style.paddingTop = top;
    RE.editor.style.paddingRight = right;
    RE.editor.style.paddingBottom = bottom;
}

RE.setTextAlign = function(align) {
    RE.editor.style.textAlign = align;
}

RE.setVerticalAlign = function(align) {
    RE.editor.style.verticalAlign = align;
}

RE.setPlaceholder = function(placeholder) {
    RE.editor.setAttribute('placeholder', placeholder);
}

RE.updatePlaceholder = function(){
    //判断placeholder
    if(RE.isHTMLEmpty()){
        RE.editor.classList.add('re_placeholder');
    }else{
        RE.editor.classList.remove('re_placeholder');
    }
}

RE.undo = function() {
    document.execCommand('undo', false, null);
}

RE.redo = function() {
    document.execCommand('redo', false, null);
}

RE.setBold = function() {
    /**标题 图片 视频 不能被设置为粗体**/
    var node = RE.getSelectedBaseNode();
    if(RE.containsTag(node, 'iframe') ||  RE.containsTag(node, 'img') ||  RE.containsTag(node, 'h3') || RE.isInTag(node,['h1' ,'h2', 'h3']) )return;
    var hasHeading = RE.isInTag(node,['h1' ,'h2', 'h3']);
    if(hasHeading && hasHeading.is){
        return;
    }

    document.execCommand('bold', false, null);
    RE.contentChanged({});
}

RE.setItalic = function() {
    document.execCommand('italic', false, null);
    RE.contentChanged({});
}

RE.setUnorderedList = function() {

     var node = RE.getSelectedBaseNode();
     if(RE.containsTag(node, 'iframe') ||  RE.containsTag(node, 'img') ||  RE.containsTag(node, 'blockquote') )return;

    // h2、block、list 不可以工程，设置其中一个都需要取消另外两个
    var formatBlock = document.queryCommandValue('formatBlock');
    if (formatBlock == 'h2') {
        RE.setHeading(formatBlock);
    }
    if (formatBlock == 'h3') {
        RE.setHeading(formatBlock);
    }
    if (formatBlock == 'blockquote') {
        RE.setBlockquote();
    }

    document.execCommand('InsertUnorderedList', false, null);

    /** 无序列表外不能嵌套h3**/
    var originalHeadNode = RE.getSelectedFirstParentNode('h3');
    var hlNodes = RE.getChildNodes(originalHeadNode, 'ul');
    if(typeof hlNodes != "undefined" && hlNodes.length > 0){
        var targetHlNode = hlNodes[0];
        originalHeadNode.parentNode.replaceChild(targetHlNode, originalHeadNode);

        /** trim &nbsp; **/
        for(i=0;i<targetHlNode.childNodes.length;i++){
           var nodeItem = targetHlNode.childNodes[i];
           if(nodeItem.nodeName.toLowerCase() == "li"){
              nodeItem.innerHTML = nodeItem.innerHTML.replace(/^(&nbsp;|\s)+/g, '').replace(/(&nbsp;|\s)+$/g, '');
           }
        }
    }
    console.log("setUnorderedList innerHTML >>> " + RE.getHtml());
    RE.contentChanged({});
    wereadBridge.handleWithRichEditor('onHtmlChange',{'param' : RE.getHtml()}, '', '');
    wereadBridge.confirmDispatchMessage();
}

RE.getChildNodes = function(parentNode, tagName){
  if(typeof parentNode != "undefined"){
     return parentNode.getElementsByTagName(tagName);
  }
}

RE.setOrderedList = function() {
    document.execCommand('InsertOrderedList', false, null);
    RE.contentChanged({});
}

RE.setHeading = function(heading) {

    //包含img iframe标签不能设置格式
    var node = RE.getSelectedBaseNode();
    if( document.queryCommandValue('bold') == 'true' || RE.isInTag(node,['b' ,'bold', 'strong']) )return;
    if(RE.containsTag(node, 'iframe') ||  RE.containsTag(node, 'img'))return;

    // h2、block、list 不可以共存，设置其中一个都需要取消另外两个
    var formatBlock = document.queryCommandValue('formatBlock');
    if (RE.isCommandEnabled('insertUnorderedList')) {
        RE.setUnorderedList();
    }
    if (formatBlock == 'blockquote') {
        RE.setBlockquote();
    }
    var formatTag = heading;
    var formatBlock = document.queryCommandValue('formatBlock');
    if (formatBlock.length > 0 && formatBlock.toLowerCase() == formatTag) {
        document.execCommand('formatBlock', false, '<p>');
    } else {
        document.execCommand('formatBlock', false, '<' + formatTag + '>');
        /** 覆盖粗体格式， 会合并所选中的段落**/
        // var headNode = RE.getSelectedFirstParentNode(formatTag);
        // if(headNode){
        //      headNode.innerHTML = headNode.innerText;
        // }
    }
    console.log("innerHTML >>> " + RE.getHtml());
    RE.contentChanged({});
    wereadBridge.handleWithRichEditor('onHtmlChange',{'param' : RE.getHtml()}, '', '');
    wereadBridge.confirmDispatchMessage();
}

RE.setBlockquote = function() {

    var node = RE.getSelectedBaseNode();
    if(RE.containsTag(node, 'iframe') ||  RE.containsTag(node, 'img') || RE.containsTag(node, 'ul'))return;
    // h2、block、order 不可以工程，设置其中一个都需要取消另外两个
    var formatBlock = document.queryCommandValue('formatBlock');
    if (RE.isCommandEnabled('insertUnorderedList')) {
        RE.setUnorderedList();
    }
    if (formatBlock == 'h2') {
        RE.setHeading('h2');
    }
    if (formatBlock == 'h3') {
        RE.setHeading('h3');
    }

    var selection = document.getSelection();
    var range = selection.getRangeAt(0).cloneRange();
    var parentElement = range.commonAncestorContainer;

    var inQuoteBlock = RE.isInTag(parentElement, 'blockquote');
    if (inQuoteBlock.is) {
        document.execCommand('formatBlock', false, '<p>')
//        if(window.getSelection().toString().length == 0){
//            document.execCommand('insertHTML', false, '&zwnj;');
//        }
    } else {
        if(!RE.containsTag(node, 'blockquote') ) {
            document.execCommand('formatBlock', false, '<blockquote>')
        }
        
    }
    RE.contentChanged({});
}

// 文章标题
RE.showArticleTitle = function(tag){
    articleTitle.style.display = tag ? 'block': 'none';
}
RE.getArticleTitle = function(){
    // 过滤尖括号for xss
    return articleTitleInput.value.replace(/</g, '&lt;')
                                  .replace(/>/g, '&gt;');
}
RE.calculateArticleTitleLength = function(str){
    var ret = 0;
    for (var i = 0, len = str.length; i < len; i++)
    {
        var code = str[i].charCodeAt(0);
        var char = str[i];
        if ((code >= 97 && code <= 122) || (code >= 65 && code <= 90) || (/\d+/.test(char)))
        {
            ret += 0.5;
            continue;
        }
        ret += 1;
    }
    return Math.floor(ret);
}

RE.updateArticleTitleHeight = function() {
    articleTitleInput.style.height = '0px';
    articleTitleInput.style.height = articleTitleInput.scrollHeight + 'px';
}

RE.articleTitleInputMaxLength = 0;
RE.handleArticleChange = function(e){
    var str = articleTitleInput.value;
    if (str.indexOf('\n') > -1) {
        str = str.replace('\n', '');
        RE.setArticleTitle(str);
    }
    var originLength = str.length;
    var specialLength = RE.calculateArticleTitleLength(str);
    if((specialLength >= 30) && (RE.articleTitleInputMaxLength == 0)){
        RE.articleTitleInputMaxLength = originLength;
        articleTitleInput.setAttribute('maxlength', originLength);
    }
    if(specialLength < 30){
        RE.articleTitleInputMaxLength = 0;
        articleTitleInput.removeAttribute('maxlength');
    }
    RE.updateArticleTitleHeight();
    wereadBridge.handleWithRichEditor('onArticleTitleChange',{'param' : RE.getArticleTitle()}, '', '');
    wereadBridge.confirmDispatchMessage();
}
RE.handleArticleKeyDown = function(e){
    if(e.keyCode == 13){
        // 禁止回车
        e.preventDefault();
        var currentTitleStr = articleTitleInput.value.replace(/^\s\s*/, '').replace(/\s\s*$/, ''); // trim
        if(currentTitleStr.length > 0){
            // 当前title值有效,则focus到editor
            RE.focusEditor();
        }
    }
}
articleTitleInput.addEventListener('input', RE.handleArticleChange);
articleTitleInput.addEventListener('keydown', RE.handleArticleKeyDown);


RE.generateEmptyPara = function(){
    var p = document.createElement('p');
    p.innerHTML = '<br>';
    return p;
}

RE.insertVideo = function(url) {
    /*var iframeNode = document.createElement('iframe');
    iframeNode.setAttribute('src', url);
    iframeNode.setAttribute('height', '400px');
    iframeNode.setAttribute('width', '100%');*/

    var html = '<p><iframe class="orderTicket" src="' + url + '" width="100%" frameborder="0"></iframe></p>';
    // RE.insertHTML('<p><br/></p>')
    // RE.insertHTML(html);
    document.execCommand('insertHTML', false, html);
    RE.contentChanged({});
}

RE.updateImageSrc = function(localUri, serverUrl) {
    var images = document.getElementsByTagName('img');
    for (var i=0;i<images.length;i++) {
        if(images[i].getAttribute('src') == localUri) {
            images[i].setAttribute('src', serverUrl);
        }
    }
    RE.contentChanged({});
    wereadBridge.handleWithRichEditor('onArticleTextChange',{'param' : RE.getArticleText()}, '', '');
    wereadBridge.handleWithRichEditor('onTextChange',{'param' : RE.getText()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlChange',{'param' : RE.getHtml()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlForEpubChange',{'param' : RE.getHtmlForEpub()}, '', '')
    wereadBridge.handleWithRichEditor('onTextContentLengthChange',{'param' : RE.getArticleText().replace(/(^\s*)|(\s*$)/g,"").length}, '', '');
    wereadBridge.confirmDispatchMessage();
}

// 插入图片
/*
params: [img,img,img,...]
img:
{
    url:,
    w:,
    h:,
    ratio:,
    oriw:
}
*/
RE.insertImage = function(imgArray) {
    function generateSpaceNode(){
        var n = document.createTextNode('\u200D');
        return n;
    }
    function generateLineBreakNode(){
        var n = document.createElement('br');
        return n;
    }
    function findImageNextSibling(imgItem){
        var tempDom = document.createElement('div');
        tempDom.innerHTML = imgItem.parentNode.innerHTML;
        var target = tempDom.querySelector('.re_img').nextSibling;
        return target;
    }
    function findImagePrevSibling(imgItem){
        var tempDom = document.createElement('div');
        tempDom.innerHTML = imgItem.parentNode.innerHTML;
        var target = tempDom.querySelector('.re_img').previousSibling;
        return target;
    }
    function resetImageParentNodeHtml(imgItem){
        var pnode = imgItem.parentNode,
            tempDom = document.createElement('div');
        tempDom.innerHTML = pnode.innerHTML;
        pnode.innerHTML = tempDom.innerHTML;
    }
    var imgItem = document.createElement('p'),
        imgItemContent = '',
        flagId = '';
    for(var i=0; i<imgArray.length; i++){
        var img = imgArray[i];
        imgItemContent += '<img ori-width="'+img.oriw+'" data-ratio="'+img.ratio+'" src="'+img.url+'" class="re_img" active="true" >';

        flagId += img.url;
    }

    imgItem.setAttribute('data-id', flagId);
    imgItem.innerHTML = imgItemContent;

    wereadBridge.handleWithRichEditor('onArticleTextChange',{'param' : imgItemContent, 'content' : imgItem.innerHTML}, '', '');
    //imgItem.innerHTML = "<img src='https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1493644540225&di=9967465a16be4de83a65891602d93d47&imgtype=0&src=http%3A%2F%2Fpic.3h3.com%2Fup%2F2017-3%2F2017325123211996080.jpg' />";

    var selection = window.getSelection(),
    range;

    if (window.getSelection().rangeCount > 0) {
        range = selection.getRangeAt(0);
    } else {
        range = document.createRange();
        if(RE.currentSelection.startContainer == 0 || RE.currentSelection.endContainer == 0){
            range.setStart(RE.editor, RE.currentSelection.startOffset);
            range.setEnd(RE.editor, RE.currentSelection.endOffset);
        }else{
            range.setStart(RE.currentSelection.startContainer, RE.currentSelection.startOffset);
            range.setEnd(RE.currentSelection.endContainer, RE.currentSelection.endOffset);
        }
    }
    var rangeNode = range.endContainer; // 光标所在的node

    if (RE.isInTag(rangeNode, ['h1' ,'h2', 'h3' ,'ul' ,'blockquote'])){
        // 列表和引用内不插书籍,把书籍看成一个独立的段落处理
        var inTagNode = RE.isInTag(rangeNode, ['h1' ,'h2', 'h3' ,'ul' ,'blockquote']).tagNode;
        imgItem.removeAttribute('data-id');
        if (inTagNode.textContent.length == 0) {
            // 如果当前block没有文本，则把block删掉
            inTagNode.parentNode.insertBefore(imgItem, inTagNode);
            if (imgItem.previousSibling.getAttribute('contenteditable') == 'false') {
                imgItem.parentNode.insertBefore(generateSpaceNode(), imgItem);
            }
            inTagNode.remove();
        } else {
            RE.insertAfter(imgItem, inTagNode);
        }
        if (imgItem.nextSibling) {
            range.selectNodeContents(imgItem.nextSibling);
            range.collapse();
        } else {
            var newEmptyLine = RE.generateEmptyPara();
            RE.insertAfter(newEmptyLine, imgItem);
            range.selectNodeContents(newEmptyLine);
            range.collapse(false);
        }
    }else{
        // 在第一行或者在一个p里，这里把图片和图片前后的node包个p
        range.collapse(false);
        range.insertNode(imgItem);
        var flagId = imgItem.getAttribute('data-id'),
            imgItemParentNode = imgItem.parentNode;
        resetImageParentNodeHtml(imgItem);
        var theImgItem = imgItemParentNode.querySelector('[data-id="'+flagId+'"]'),
            theImgItemPreviousSibling = null || theImgItem.previousSibling,
            theImgItemNextSibling = null || theImgItem.nextSibling;
        theImgItem.removeAttribute('data-id');
        if(imgItemParentNode == RE.editor){
            // 这是在第一行没被p包住的情况
            // 图片前面包一个p
            if(theImgItemPreviousSibling){
                if((theImgItemPreviousSibling.nodeType == 3 ) || (theImgItemPreviousSibling.nodeType == 1 && theImgItemPreviousSibling.tagName.toLowerCase() == "br")){
                    var newPreviousPara = document.createElement('p');
                    range.selectNodeContents(theImgItemPreviousSibling);
                    range.surroundContents(newPreviousPara);
                }
            }
            // 图片后面包一个p
            if(theImgItemNextSibling){
                if((theImgItemNextSibling.nodeType == 3 ) || (theImgItemNextSibling.nodeType == 1 && theImgItemNextSibling.tagName.toLowerCase() == "br")){
                    var newNextPara = document.createElement('p');
                    range.selectNodeContents(theImgItemNextSibling);
                    range.surroundContents(newNextPara);
                    range.selectNodeContents(newNextPara);
                }else{
                    range.selectNodeContents(theImgItemNextSibling);
                    range.collapse();
                }
            }else{
                var emptyLine = RE.generateEmptyPara();
                RE.insertAfter(emptyLine, theImgItem);
                range.selectNodeContents(emptyLine);
                range.collapse(false);
            }
        }else{
            // 这是在一个段落里面的
            // 先把图片挪到parent外面
            RE.insertAfter(theImgItem, imgItemParentNode);
            // 如果原来有nextSibling，则把图片原来的nextSibling包一个p并插到图片后面
            if(theImgItemNextSibling && !(theImgItemNextSibling.nodeType == 1 && theImgItemNextSibling.tagName.toLowerCase() == "br")){
                var newNextPara;
                if((theImgItemNextSibling.nodeType == 3 ) || (theImgItemNextSibling.nodeType == 1 && theImgItemNextSibling.tagName.toLowerCase() == "br")){
                    newNextPara = document.createElement('p');
                    range.selectNodeContents(theImgItemNextSibling);
                    range.surroundContents(newNextPara);
                }else{
                    newNextPara = theImgItemNextSibling;
                }
                RE.insertAfter(newNextPara, theImgItem);
            }
            if((imgItemParentNode.childNodes.length == 0) || (imgItemParentNode.innerHTML == '<br>') || (imgItemParentNode.innerText == '')){
                // 书和next移除出来后parent空了，移除掉
                imgItemParentNode.parentNode.removeChild(imgItemParentNode);
            }
            if(theImgItem.nextSibling){
                // 处理完之后重新那img的next并做相应处理
                range.selectNodeContents(theImgItem.nextSibling);
            }else{
                var newEmptyLine = RE.generateEmptyPara();
                RE.insertAfter(newEmptyLine, theImgItem);
                range.selectNodeContents(newEmptyLine);
            }
        }
    }

    RE.backuprange();
    selection.removeAllRanges();
    selection.addRange(range);

    //插完书滚动编辑器到合适的位置
    RE.calculateEditorHeightWithCaretPosition();
    selection.collapseToStart();


    RE.contentChanged({});
//    wereadBridge.handleWithRichEditor('onArticleTextChange',{'param' : RE.getArticleText()}, '', '');
    wereadBridge.handleWithRichEditor('onTextChange',{'param' : RE.getText()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlChange',{'param' : RE.getHtml()}, '', '');
//    wereadBridge.handleWithRichEditor('onHtmlForEpubChange',{'param' : RE.getHtmlForEpub()}, '', '')
//    wereadBridge.handleWithRichEditor('onTextContentLengthChange',{'param' : RE.getArticleText().replace(/(^\s*)|(\s*$)/g,"").length}, '', '');

    wereadBridge.handleWithRichEditor('onInsertImage', {'param': imgArray}, '', '');
    wereadBridge.confirmDispatchMessage();
}

// 插入书籍
RE.insertBook = function(id, title, author, cover) {

    function generateSpaceNode(){
        var n = document.createTextNode('\u200D');
        return n;
    }
    function generateLineBreakNode(){
        var n = document.createElement('br');
        return n;
    }
    // 下面两个找前后节点的方法之所以这样实现是因为
    // ios里当光标在一个文字node上移动时会把它切割，例如
    // 一个文字node：ABCDE，当光标从E后面往左移，会把它分割成
    // ABCD,E
    // ABC,D,E
    // AB,C,D,E
    // A,B,C,D,E
    // 这样如果我在ABCDE前面插入img，img的nextSibling有可能只拿到A而拿不到整个文字node，不符合预期
    function findBookNextSibling(bookItem){
        var tempDom = document.createElement('div');
        tempDom.innerHTML = bookItem.parentNode.innerHTML;
        var target = tempDom.querySelector('.re_bookItem').nextSibling;
        return target;
    }
    function findBookPrevSibling(bookItem){
        var tempDom = document.createElement('div');
        tempDom.innerHTML = bookItem.parentNode.innerHTML;
        var target = tempDom.querySelector('.re_bookItem').previousSibling;
        return target;
    }
    function resetBookItemParentNodeHtml(bookItem){
        var pnode = bookItem.parentNode,
            tempDom = document.createElement('div');
        tempDom.innerHTML = pnode.innerHTML;
        pnode.innerHTML = tempDom.innerHTML;
    }

    var bookItem = document.createElement('div');
    bookItem.className = 're_bookItem';
    bookItem.setAttribute('contenteditable', false);
    bookItem.setAttribute('data-id', id); // 点击相关的事件在rich_display.js里根据data-id处理
    bookItem.innerHTML = '<div class="re_bookItem_cover"><img class="re_bookItem_cover_img" src="' + cover + '" alt="' + title + '"></div>' +
    '<div class="re_bookItem_title">' + title + '</div>' +
    '<div class="re_bookItem_author">' + author + '</div>';

    var selection = window.getSelection(),
    range;

    if (window.getSelection().rangeCount > 0) {
        range = selection.getRangeAt(0);
    } else {
        range = document.createRange();
        if(RE.currentSelection.startContainer == 0 || RE.currentSelection.endContainer == 0){
            range.setStart(RE.editor, RE.currentSelection.startOffset);
            range.setEnd(RE.editor, RE.currentSelection.endOffset);
        }else{
            range.setStart(RE.currentSelection.startContainer, RE.currentSelection.startOffset);
            range.setEnd(RE.currentSelection.endContainer, RE.currentSelection.endOffset);
        }
    }
    var rangeNode = range.endContainer; // 光标所在的node

    if (RE.isInTag(rangeNode, 'ul') || RE.isInTag(rangeNode, 'blockquote') || RE.isInTag(rangeNode, 'h2') || RE.isInTag(rangeNode, 'h3')) {
        // 列表和引用内不插书籍,把书籍看成一个独立的段落处理
        var inTagNode = RE.isInTag(rangeNode, 'ul').tagNode ||
        RE.isInTag(rangeNode, 'blockquote').tagNode ||
        RE.isInTag(rangeNode, 'h2').tagNode ||
        RE.isInTag(rangeNode, 'h3').tagNode;

        if (inTagNode.textContent.length == 0) {
            // 如果当前block没有文本，则把block删掉
            inTagNode.parentNode.insertBefore(bookItem, inTagNode);
            if (bookItem.previousSibling.getAttribute('contenteditable') == 'false') {
                bookItem.parentNode.insertBefore(generateSpaceNode(), bookItem);
            }
            inTagNode.remove();
        } else {
            RE.insertAfter(bookItem, inTagNode);
        }
        if (bookItem.nextSibling) {
            range.selectNodeContents(bookItem.nextSibling);
            range.collapse();
        } else {
            var newEmptyLine = RE.generateEmptyPara();
            RE.insertAfter(newEmptyLine, bookItem);
            range.selectNodeContents(newEmptyLine);
            range.collapse(false);
        }
    }else{
        // 在第一行或者在一个p里，这里把图片和图片前后的node包个p
        range.collapse(false);
        range.insertNode(bookItem);
        var flagId = bookItem.getAttribute('data-id'),
            bookItemParentNode = bookItem.parentNode;
        resetBookItemParentNodeHtml(bookItem);
        var theBookItem = bookItemParentNode.querySelector('[data-id="'+flagId+'"]'),
            theBookItemPreviousSibling = null || theBookItem.previousSibling,
            theBookItemNextSibling = null || theBookItem.nextSibling;
        if(bookItemParentNode == RE.editor){
            // 这是在第一行没被p包住的情况
            // 图片前面包一个p
            if(theBookItemPreviousSibling){
                if((theBookItemPreviousSibling.nodeType == 3 ) || (theBookItemPreviousSibling.nodeType == 1 && theBookItemPreviousSibling.tagName.toLowerCase() == "br")){
                    var newPreviousPara = document.createElement('p');
                    range.selectNodeContents(theBookItemPreviousSibling);
                    range.surroundContents(newPreviousPara);
                }
            }else{
                theBookItem.parentNode.insertBefore(generateSpaceNode(), theBookItem);
            }
            // 图片后面包一个p
            if(theBookItemNextSibling){
                if((theBookItemNextSibling.nodeType == 3 ) || (theBookItemNextSibling.nodeType == 1 && theBookItemNextSibling.tagName.toLowerCase() == "br")){
                    var newNextPara = document.createElement('p');
                    range.selectNodeContents(theBookItemNextSibling);
                    range.surroundContents(newNextPara);
                    range.selectNodeContents(newNextPara);
                }else{
                    range.selectNodeContents(theBookItemNextSibling);
                    range.collapse();
                }
            }else{
                var emptyLine = RE.generateEmptyPara();
                RE.insertAfter(emptyLine, theBookItem);
                range.selectNodeContents(emptyLine);
                range.collapse(false);
            }
        }else{
            // 这是在一个段落里面的
            // 先把图片挪到parent外面
            RE.insertAfter(theBookItem, bookItemParentNode);
            // 如果原来有nextSibling，则把图片原来的nextSibling包一个p并插到图片后面
            if(theBookItemNextSibling && !(theBookItemNextSibling.nodeType == 1 && theBookItemNextSibling.tagName.toLowerCase() == "br")){
                var newNextPara;
                if((theBookItemNextSibling.nodeType == 3 ) || (theBookItemNextSibling.nodeType == 1 && theBookItemNextSibling.tagName.toLowerCase() == "br")){
                    newNextPara = document.createElement('p');
                    range.selectNodeContents(theBookItemNextSibling);
                    range.surroundContents(newNextPara);
                }else{
                    newNextPara = theBookItemNextSibling;
                }
                RE.insertAfter(newNextPara, theBookItem);
            }
            if((bookItemParentNode.childNodes.length == 0) || (bookItemParentNode.innerHTML == '<br>') || (bookItemParentNode.innerText == '')){
                // 书和next移除出来后parent空了，移除掉
                bookItemParentNode.parentNode.removeChild(bookItemParentNode);
            }
            if(theBookItem.nextSibling){
                // 处理完之后重新那book的next并做相应处理
                range.selectNodeContents(theBookItem.nextSibling);
            }else{
                var newEmptyLine = RE.generateEmptyPara();
                RE.insertAfter(newEmptyLine, theBookItem);
                range.selectNodeContents(newEmptyLine);
            }
            if(!theBookItem.previousSibling || (theBookItem.previousSibling.getAttribute('contenteditable') == 'false')){
                theBookItem.parentNode.insertBefore(generateSpaceNode(), theBookItem);
            }
        }
    }

    RE.backuprange();
    selection.removeAllRanges();
    selection.addRange(range);
    selection.collapseToStart();

    //插完书滚动编辑器到合适的位置
    RE.calculateEditorHeightWithCaretPosition();
    RE.contentChanged({});

    //回调
    wereadBridge.handleWithRichEditor('onArticleTextChange',{'param' : RE.getArticleText()}, '', '');
    wereadBridge.handleWithRichEditor('onTextChange',{'param' : RE.getText()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlChange',{'param' : RE.getHtml()}, '', '');
    wereadBridge.handleWithRichEditor('onHtmlForEpubChange',{'param' : RE.getHtmlForEpub()}, '', '')
    wereadBridge.handleWithRichEditor('onTextContentLengthChange',{'param' : RE.getArticleText().replace(/(^\s*)|(\s*$)/g,"").length}, '', '');
    wereadBridge.confirmDispatchMessage();
}

RE.removeExcluedFlag = function(str) {
    str = str.replace(/blockquote>/g,'p>')
             .replace(/h3>/g,'p>')
             .replace(/<ul>/g,'')
             .replace(/<\/ul>/g,'')
             .replace(/li>/g,'p>')
    str = correctArticle(str, {pInQuote: true});
    return str;
}

RE.insertHTML = function(html) {

    setTimeout(function(){
        //blockqupte h3 <li> 标签不能共存
        
     var sel = getSelection();
     var focusNode = sel.focusNode;
     var needRemoveFlag = false;
     if (typeof(focusNode) != 'undefined') {
          var inQuoteBlock = RE.isInTag(focusNode, 'blockquote');
             if (inQuoteBlock.is) {
                 needRemoveFlag = true;
             }
     }
 
     var formatBlock = document.queryCommandValue('formatBlock');
     if (RE.isCommandEnabled('insertUnorderedList')) {
         needRemoveFlag = true;
     }
     if (formatBlock == 'h3') {
         needRemoveFlag = true;
     }
 
     if (needRemoveFlag) {
         html = RE.removeExcluedFlag(html);
     } else {
         var range = getSelection().getRangeAt(0).cloneRange()
         var endOffset = range.endOffset;
         if (endOffset != 0) {//不是起始位置
             if (html.indexOf('<blockquote>') == 0) {
                 document.execCommand('insertHTML', false, '<p><br></p>');
             }
         }
     }
 
     if(!focusNode.nodeValue){
         document.execCommand('insertHTML', false, html);
     }
     var currentTagName = RE.currentSelection.startContainer.tagName
     if(currentTagName== 'B' || currentTagName == 'STRONG' || currentTagName === 'BOLD' ){
         document.execCommand('bold', false, null);
     }
     RE.contentChanged({});
     //判断placeholder
     RE.updatePlaceholder();
     //RE.calculateEditorHeightWithCaretPosition();
        },30);
}

RE.insertText = function(text) {
    document.execCommand('insertText', false, text);
    RE.calculateEditorHeightWithCaretPosition();
}

RE.insertLink = function (text, href, title) {

    if(!RE.isFocus()){
        RE.focusEditor();
    }

    /*
     href="topic:name/at:vid" 初始状态"topic:0/at:0"
     title="#content#/@username"  初始状态"##/@\u00A0"
     初始化后title,href在选中用户或者选择话题的时候才进行更新
     */
    var selection = document.getSelection(),
        currentNode = selection.focusNode;
    if(selection && selection.rangeCount > 0){
        var aElement = document.createElement('a');
        aElement.setAttribute('href', href?href:'');
        aElement.setAttribute('title', title?title:'');
        aElement.className = 're_link';
        if(RE.currentEditingLink){
            // 避免重复link
            aElement.innerText = text?text:'';
            RE.insertAfter(aElement, RE.currentEditingLink);
            var range = document.createRange();
            range.selectNode(aElement);
            range.collapse(false);
        }else{
            // 纯文本
            var range = selection.getRangeAt(0).cloneRange();
            range.surroundContents(aElement); // surroundContents后link的innertText为光标选择的内容，需要重新设定为需要的text
            aElement.innerText = text?text:'';
            range.collapse(false);
        }
        selection.removeAllRanges();
        selection.addRange(range);
    }
}

// unlink光标前的link
RE.unlink = function() {

    // document.execCommand('unlink', false, false);
    if (RE.currentEditingLink) {

        RE.unlinkFor(RE.currentEditingLink);

    }

}
// unlink光标后的link
RE.unlinkAfter = function() {

    // document.execCommand('unlink', false, false);
    if (RE.currentEditingAfterLink) {

        RE.unlinkFor(RE.currentEditingAfterLink);

    }
}

// unlink指定的link
RE.unlinkFor = function(link) {
    var parent = link.parentElement,
        newEl = document.createTextNode(link.innerText);

    var selection = window.getSelection();
    var range = document.createRange();

    range.selectNode(link);
    selection.removeAllRanges();
    selection.addRange(range);

    document.execCommand('unlink', false, null);
    link = null;

    RE.restorerange();
}

RE.updateLink = function(text, href, title) {
    if (RE.currentEditingLink) {
        //replace innerhtml
        var currentLink = RE.currentEditingLink;
        currentLink.setAttribute('href', href);
        currentLink.setAttribute('title', title);
        currentLink.innerHTML = text;
        //move cursor
        var iteratorNode = currentLink;
        while(iteratorNode.lastChild) {
            iteratorNode = iteratorNode.lastChild;
        }
        var range = document.createRange();
        range.selectNodeContents(iteratorNode);
        range.collapse(false);
        var len = iteratorNode.textContent.length;
        range.setStart(range.startContainer,len);
        range.setEnd(range.endContainer,len);
        var selection = window.getSelection();

        selection.removeAllRanges();
        selection.addRange(range);
    }
    RE.contentChanged({});
}

RE.updateLinkAttribute = function(href, title) {
    if (RE.currentEditingLink) {
        var currentLink = RE.currentEditingLink;
        currentLink.setAttribute('href', href);
        currentLink.setAttribute('title', title);
    }
}

RE.setSelectionRange = function(node, startIndex, endIndex){
    var sel = window.getSelection();
    sel.removeAllRanges();
    var range = document.createRange();
    range.setStart(node, startIndex);
    range.setEnd(node, endIndex);
    sel.addRange(range);
}

//通知js插入emoji表情
RE.insertEmoji = function(name,useImg){
    if(useImg){
        RE.insertHTML('<img src="' + useImg + '" class="re_emoji_img" />');
    } else {
        RE.insertHTML('<span class="re_emoji">['+ name +']</span>');
    }
    RE.contentChanged({});
}

// 键盘监听
RE.keyupCallback = function(e){

    if (e.keyCode != 0 || e.which != 0) {
        // 部分安卓机拿不到keycode和which，此时由app自己判断
        if (e.which != KEY_BACKSPACE_CODE){
            // 若不是退格行为，则判断当前keyup后光标前一位的字符
            var currentAnchorCode = window.getSelection().focusNode.textContent[window.getSelection().focusOffset-1];
            if (currentAnchorCode == KEY_AT_CHAR && e.which == KEY_AT_CODE){
                RE.handleAtClick();
            } else if (currentAnchorCode == KEY_HASH_CHAR && e.which == KEY_HASH_CODE){
                RE.handleTopicClick();
            }

            /** add by gongyong 6.2 **/
            if(e.which == 13 || e.keyCode == 13) {
                 RE.contentChanged(e);
            }
        }
    }else{
        wereadBridge.handleWithRichEditor('hasNoKeyCode',{'param' : 'yes'}, '', '');
        wereadBridge.confirmDispatchMessage();
    }
}

RE.delete = function() {
    document.execCommand('delete', false, null);
}

RE.prepareInsert = function() {
    RE.backuprange();
}

RE.backuprange = function(){
    var selection = window.getSelection();
    if (selection.rangeCount > 0) {
      var range = selection.getRangeAt(0);
      RE.currentSelection = {
          'startContainer': range.startContainer,
          'startOffset': range.startOffset,
          'endContainer': range.endContainer,
          'endOffset': range.endOffset};
    }
}


RE.restorerange = function(){
    var selection = window.getSelection();
    selection.removeAllRanges();
    var range = document.createRange();
    if(RE.currentSelection.startOffset > RE.currentSelection.startContainer.length){
        RE.currentSelection.startOffset = RE.currentSelection.startContainer.length;
    }
    if(RE.currentSelection.endOffset > RE.currentSelection.endContainer.length){
        RE.currentSelection.endOffset = RE.currentSelection.endContainer.length;
    }
    range.setStart(RE.currentSelection.startContainer, RE.currentSelection.startOffset);
    range.setEnd(RE.currentSelection.endContainer, RE.currentSelection.endOffset);
    selection.addRange(range);
}

RE.isCommandEnabled = function(commandName) {
    return document.queryCommandState(commandName);
}

RE.removeSpecifiedLink = function(link) {
    var parent = link.parentElement;
    if (parent) {
        var newEl = document.createTextNode(link.innerText);
        parent.insertBefore(newEl,link);
        parent.removeChild(link);
    }
}
RE.contentChanged = function(e) {

    RE.updatePlaceholder();

    var items = [];

    if (RE.isCommandEnabled('bold')) { items.push('bold'); }
    if (RE.isCommandEnabled('italic')) { items.push('italic'); }
    if (RE.isCommandEnabled('insertOrderedList')) { items.push('orderedList'); }
    if (RE.isCommandEnabled('insertUnorderedList')) { items.push('unorderedList'); }
    if (RE.isCommandEnabled('justifyCenter')) { items.push('justifyCenter'); }
    if (RE.isCommandEnabled('justifyLeft')) { items.push('justifyLeft'); }
    if (RE.isCommandEnabled('justifyRight')) { items.push('justifyRight'); }

    if(document.queryCommandEnabled('undo')) {
        items.push('undo');
    }

    if(document.queryCommandEnabled('redo')) {
        items.push('redo');
    }

    var formatBlock = document.queryCommandValue('formatBlock');
    if (formatBlock.length > 0) { items.push(formatBlock); }

    if (typeof(e) != 'undefined') {
        var node = RE.getSelectedNode();
        if (node) {
            var nodeName = node.nodeName.toLowerCase();
            // Link
            if (RE.isSpecifiedTag(node, 'a')) {
                RE.currentEditingLink = node;
            } else if (RE.isInTag(node, 'a').is) {
                var plink = RE.isInTag(node, 'a').tagNode;
                RE.currentEditingLink = plink;
            } else {
                RE.currentEditingLink = null;
            }
            // 判断光标后面是不是link
            if(node.nextElementSibling || node.nextSibling){
                var next = node.nextElementSibling || node.nextSibling;
                if(next && RE.isSpecifiedTag(next, 'a')){
                    RE.currentEditingAfterLink = next;
                    var title = next.getAttribute('title');
                    var href = next.getAttribute('href');
                    if (href != undefined) { items.push('afterLink:' + href); }
                    if (title !== undefined) { items.push('afterLink-title:' + title); }
                    items.push('afterLink-text:' + next.innerText)
                    items.push('afterLink-html:' + next.innerHTML)
                } else if(RE.isInTag(node, 'a').is){
                    var plink = RE.isInTag(node, 'a').tagNode;
                    RE.currentEditingAfterLink = plink;
                    var title = plink.getAttribute('title');
                    var href = plink.getAttribute('href');
                    if (href != undefined) { items.push('afterLink:' + href); }
                    if (title !== undefined) { items.push('afterLink-title:' + title); }
                    items.push('afterLink-text:' + plink.innerText);
                    items.push('afterLink-html:' + next.innerHTML);
                }else{
                    RE.currentEditingAfterLink = null;
                }
            }

            // Blockquote
            if (RE.isSpecifiedTag(node, 'blockquote')) {
                items.push('indent');
            }
            // Image
            if (RE.isSpecifiedTag(node, 'img')) {
                RE.currentEditingImage = node;
                var src = node.getAttribute('src');
                var alt = node.getAttribute('alt');
                if (src != undefined) { items.push('image:' + src); }
                if (alt != undefined) { items.push('image-alt:' + node.getAttribute('alt')); }
            } else {
                RE.currentEditingImage = null;
            }
        }
    }

    if (RE.currentEditingLink) {
        //放在这里是因为保证即使是失焦，也能传递Link数据
        items.push('isEditingLink:1')
        var title = RE.currentEditingLink.getAttribute('title');
        var href = RE.currentEditingLink.getAttribute('href');
        if (href != undefined) { items.push('link:' + href); }
        if (title !== undefined) { items.push('link-title:' + title);}
        items.push('link-text:' + RE.currentEditingLink.innerText);
        items.push('link-html:' + RE.currentEditingLink.innerHTML)

    } else {
        items.push('isEditingLink:0')
    }

    if (window.getSelection().toString().length > 0) {
        items.push('hasSelectedText');
    }

    /** add by gongyong 6.2 **/
    if(e.which == 13 || e.keyCode == 13) {
        items.push("enterClicked");
    }

    //RE._alert(items);

    wereadBridge.handleWithRichEditor('onSelectionChange',{'param' : items.join(RE.dataSeperator)}, '', '');
    wereadBridge.confirmDispatchMessage();
}

RE.handleAtClick = function() {
    var items = [];
    RE.fillEditingStatus(items);
    wereadBridge.handleWithRichEditor('onAtClicked', {'param' : items.join(RE.dataSeperator)}, '', '');
    wereadBridge.confirmDispatchMessage();
}

RE.handleTopicClick = function() {
    var items = [];
    RE.fillEditingStatus(items);
    wereadBridge.handleWithRichEditor('onTopicClicked', {'param' : items.join(RE.dataSeperator)}, '', '');
    wereadBridge.confirmDispatchMessage();
}

RE.fillEditingStatus = function(items){
    if (RE.currentEditingLink) {
        items.push('isEditingLink:1')
    } else {
        items.push('isEditingLink:0')
    }
}

RE.isEditingLink = function() {
    if (RE.currentEditingLink) {
        return true;
    } else {
        return false;
    }
}

RE.isFocus = function(){
    return document.activeElement === RE.editor;
}

RE.focus = function() {

    // 这个focus要处理光标的位置
    if(RE.currentSelection.startContainer != 0) {
        RE.restorerange();
        RE.editor.focus();

        return;
    }

    var range = document.createRange();
    range.selectNodeContents(RE.editor);
    range.collapse(false);
    var selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);



    RE.editor.focus();
    RE.backuprange();
}

RE.focusEditor = function() {
    // 这个focus没有有处理光标的位置
    RE.editor.focus()
}

RE.blurEditor = function() {
    RE.editor.blur();
    RE.fakeEditor.focus();
    RE.fakeEditor.blur();
}

RE.clearEditorFocus = function() {
    RE.editor.blur();
}

//这里将做表情的解码 l_f_s微笑r_f_s --》[微笑]
RE.editor.decodeFaceStr = function(str) {

    var regular = RE.faceSplitStrLeft+'.{1,3}';
    regular = regular + RE.faceSplitStrRight;

    if(typeof(str) != 'undefined' && str) {

        var matchedArr = str.match(regular);
        if(matchedArr && matchedArr.length > 0) {

            for(var index = 0;index < matchedArr.length;index++) {
                var matchedStr = matchedArr[index]
                while(matchedStr && str && str.indexOf(matchedStr) != -1) {
                    if(matchedStr && matchedStr.length > RE.faceSplitStrRight.length + RE.faceSplitStrLeft.length) {
                        var originalStr = matchedStr.substr(RE.faceSplitStrLeft.length,matchedStr.length - RE.faceSplitStrRight.length - RE.faceSplitStrLeft.length);
                        originalStr = '['+ originalStr;
                        originalStr = originalStr + ']';
                        str = str.replace(matchedStr,originalStr);
                    } else {
                        break;
                    }
                }

            }

        }

    }
    return str;
};

RE.editor.addEventListener('paste', function(e) {
    e.preventDefault();
    wereadBridge.handleWithRichEditor('onPaste', {'param' : ''}, '', '');
    wereadBridge.confirmDispatchMessage();
});

//由于Android,@和#需要跳出页面,回来时WebView请求focus时自动滚动到顶部,因此需要重新滚动至光标处
RE.triggerCursorScroll = function() {
    wereadBridge.handleWithRichEditor('onCursorScroll', {'param' : 'scroll'}, '', '');
    wereadBridge.confirmDispatchMessage();
}

RE.removeFormat = function() {
    document.execCommand('removeFormat', false, null);
}

// title tag for reader in app
RE.generateTitleTag = function(){
}

RE.setFontSize = function(sizeType) {
    RE.toggleEditorClass(sizeType, ['f10', 'f12','f14', 'f16', 'f18', 'f20','f22'],RE.editor);
}

RE.setTheme = function(themeType) {
    var bodyEle = document.body;
    RE.toggleEditorClass(themeType, ['dark','blue','yellow','red','white','green'],bodyEle);
}

RE.toggleEditorClass = function(classType, allTypes,ele) {
    if(classType && allTypes) {
        var found = false;
        for(i in allTypes) {
            if(allTypes[i] == classType) {
                found = true;
                break;
            }
        }
        if(!found) {
            return ;
        }

        for(i in allTypes) {
            ele.classList.remove(allTypes[i]);
        }
        ele.classList.add(classType);
    }
}

// Event Listeners
RE.editor.addEventListener('keyup', RE.keyupCallback);
RE.editor.addEventListener('keydown', RE.keydownCallback);
RE.editor.addEventListener('click', RE.contentChanged);

RE.init();

RE._alert = function(obj){
   var start = "Console-Msg : ";
   var ss = [];
   if(obj) {
      if(typeof obj == 'object') {
         var keys = Object.keys(obj);
          //console.log(keys);
         for(var k in obj) {
             //console.log(k);
            var s = k + "=" + obj[k];
            ss.push(s);
         }
      }else {
         ss.push(obj);
      }
   }

    //console.log(ss);

   var msg = ss.join(" | ");
    msg = start + msg;
   console.log(msg);
};

RE.printAllHTML = function() {
  console.log("AllHTML >>>>> " + document.getElementsByTagName('html')[0].innerHTML);
}


