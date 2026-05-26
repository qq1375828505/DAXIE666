<script type="text/javascript">
    (function() /** {$b5167ccadfb66ea3ba95d92d7c9946c9} */{
    WeReadBridge = function() /** {$b9c7abd4d524a31563f1f27b768c47a9} */ {
        this._sendMessageQueue = [];
        this._callback_count = 1000;
        this._callback_map = {};
        this.available_func = {};
        this._iframe = document.createElement("iframe");
        this._iframe.setAttribute("id", "iframe");
        this._iframe.setAttribute("style","position:absolute;top:0;left:0;width:1px;height:1px;visibility:hidden;");
        this._QUEUE_HAS_MESSAGE_URL = 'wereadapijs://dispatch_message/';
        document.body.appendChild(this._iframe);

        this._resultIframe = document.createElement("iframe");
        this._resultIframe.setAttribute("id", "_resultIframe");
        this._resultIframe.setAttribute("style","position:absolute;top:0;left:0;width:1px;height:1px;visibility:hidden;");
        this._resultIframe._SET_RESULT_URL = 'wereadapijs://private/setresult/';
        document.body.appendChild(this._resultIframe);
    }

    window.callback = {}
    function wrapCallback(name, callback) {
        window.callback[name] = callback;
        return name;
    }

    WeReadBridge.prototype.handleWithRichEditor = function(apiName, params,successCallback, failCallback) {
        //alert("hi");
        this._call(apiName,params,function(successOrNot, result) {
            if (typeof successCallback === "function" || typeof failCallback === "function") {
                self._handleCallback(result, successOrNot, successCallback, failCallback);
            };
        });
    }


    WeReadBridge.prototype.fetchQueue = function() /** {$4a202e1afc4b36610e87f574e5478e15} */ {
        var messageQueueString = JSON.stringify(this._sendMessageQueue);
        this._sendMessageQueue = [];
        this._setResultValue('fetchqueue', messageQueueString);
        return messageQueueString;
    }


    WeReadBridge.prototype._setResultValue = function(scene, result) /** {$23e4b67694084da787d5fa5c739b9a66} */ {
        // Android 通过另一个iframe上传数据
        if (result === undefined) {
            result = '';
        }
        this._resultIframe.src = this._resultIframe._SET_RESULT_URL + scene + '&' + this._base64Encode(this._utf8Encode(result));
    }
     // public method for url encoding
    WeReadBridge.prototype._utf8Encode = function(str) /** {$9da9355c0a506c2d0c6dd40c35ea7fb6} */ {
        str = str.replace(/\r\n/g, "\n");
            var utftext = "";

            for (var n = 0; n < str.length; n++) {

                var c = str.charCodeAt(n);

                if (c < 128) {
                    utftext += String.fromCharCode(c);
                } else if ((c > 127) && (c < 2048)) {
                    utftext += String.fromCharCode((c >> 6) | 192);
                    utftext += String.fromCharCode((c & 63) | 128);
                } else {
                    utftext += String.fromCharCode((c >> 12) | 224);
                    utftext += String.fromCharCode(((c >> 6) & 63) | 128);
                    utftext += String.fromCharCode((c & 63) | 128);
                }

            }

            return utftext;
    }

    WeReadBridge.prototype._base64Encode = function(str) /** {$caa95e8456b5cda1716514776a0bf77a} */ {
        //base64编码
        var base64encodechars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        if (str === undefined) {
            return str;
        }
        var out, i, len;
        var c1, c2, c3;
        len = str.length;
        i = 0;
        out = "";
        while (i < len) {
            c1 = str.charCodeAt(i++) & 0xff;
            if (i == len) {
                out += base64encodechars.charAt(c1 >> 2);
                out += base64encodechars.charAt((c1 & 0x3) << 4);
                out += "==";
                break;
            }
            c2 = str.charCodeAt(i++);
            if (i == len) {
                out += base64encodechars.charAt(c1 >> 2);
                out += base64encodechars.charAt(((c1 & 0x3) << 4) | ((c2 & 0xf0) >> 4));
                out += base64encodechars.charAt((c2 & 0xf) << 2);
                out += "=";
                break;
            }
            c3 = str.charCodeAt(i++);
            out += base64encodechars.charAt(c1 >> 2);
            out += base64encodechars.charAt(((c1 & 0x3) << 4) | ((c2 & 0xf0) >> 4));
            out += base64encodechars.charAt(((c2 & 0xf) << 2) | ((c3 & 0xc0) >> 6));
            out += base64encodechars.charAt(c3 & 0x3f);
        }
        return out;
    }



    WeReadBridge.prototype._sendMessage = function(message) /** {$0685a6a5b33dbf2f615a5ae1faedb0c8} */ {
        this._sendMessageQueue.push(message);
        this._iframe.src = this._QUEUE_HAS_MESSAGE_URL;
    }

    WeReadBridge.prototype.handleMessage = function(message) /** {$623f3ca7480b38b659e4f32c858046f4} */ {
        var callbackId = message["callbackId"];
        if (!callbackId || typeof callbackId !== 'string') {
            return;
        }
        var successOrNot = message["successOrNot"];
        var params = message["params"];
        if (typeof this._callback_map[callbackId] === "function"){
            this._callback_map[callbackId](successOrNot,params);
            delete this._callback_map[callbackId];
        }
    }

    WeReadBridge.prototype._call = function(func, params, callback) /** {$0a78d8c17b87d24c599c91b498b8662b} */ {
        if (!func || typeof func !== "string") {
            return;
        }

        if (typeof params !== "object") {
            params = {};
        }

        var msgObj = {"func":func,"params":params};

        var callbackID = (this._callback_count++).toString();
        params["callbackId"] = callbackID;

        if (typeof callback === "function") {
            this._callback_map[callbackID] = callback;
            msgObj["callbackId"] = callbackID;
        }
        this._sendMessage(JSON.stringify(msgObj));
    }

    WeReadBridge.prototype._handleCallback = function(result, successOrNot, successCallback, failCallback) {
        // Android 返回 JSON String，在这里转JSON
        resultJSON = (typeof result == 'string') ? JSON.parse(result) : result;
        if (successOrNot) {
            successCallback(resultJSON);
        } else {
            failCallback(resultJSON);
        }
    }

    WeReadBridge.prototype.onReady = function(func) /** {$9ce323af53931aa37c8788958d68f687} */ {
        !_isReady && _bindReadyFuns.unshift([this, func]);
    }
    WeReadBridge.prototype.bindReady = function(func) /** {$d3b152348187da57f207a3a3eb27fa54} */ {
        !_isReady ? _bindReadyFuns.unshift([this, func]) : func.call(this);
    }
    WeReadBridge.prototype.isReady = function() /** {$9c23e94ea3f2aafaae1c349574569f78} */ {
        return _isReady;
    }
    WeReadBridge.prototype.isAvailable = function(apiName) /** {$67e34482192a8170c150ec414ed4ba7a} */ {
        return !!(_WeReadBridgeInfo && _WeReadBridgeInfo["apis"][apiName]);
    }
     var _isReady, _WeReadBridgeInfo, _bindReadyFuns = [],
         _onReady = function() /** {$d1b53430a7b4de2d74d12a81eec715ec} */ {
             _WeReadBridgeInfo = window["__QMB_INFO__"];
             if (_isReady) return;
             _isReady = true;
             var _funcParams;
             while (_funcParams = _bindReadyFuns.pop()) {
                 _funcParams[1].call(_funcParams[0]);
             };
         };
     window["wereadBridge"] = new WeReadBridge();
     if (window["__WRB_INFO__"]) {
         _onReady();
     } else {
         window["__WRB_INFO_CALL__"] = function() /** {$4f54cf9d496e3e999912adfb7b5d37b7} */ {
             _onReady();
         };
     }
})();
    </script>
    <script>
    var RDisplay = {};

    RDisplay.editor = document.getElementById('editor');
    RDisplay.dataSeperator = "r_e_ds";

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
    RDisplay.onImageClick = function(imgIndex){
        // 传回去一个字符串: [index, URL0, URL1, URL2].join(separator)
        var paramString = imgIndex + RDisplay.dataSeperator + allImageSrcString;
        wereadBridge.handleWithRichEditor("gotoImageDetail", {"param" : paramString}, "", "");
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
    var allImageSrcString = '';
    if(reImgs.length > 0){
        var allImgSrc = [];
        for(var i = 0; i<reImgs.length; i++){
            var img = reImgs[i];
            var src;
            if(img.getAttribute('data-src')){
                src = img.getAttribute('data-src');
            } else {
                src = img.getAttribute('src');
            }
            allImgSrc.push(src);
            img.setAttribute('onclick', 'RDisplay.onImageClick(' + i + ')');
        }
        allImageSrcString = allImgSrc.join(RDisplay.dataSeperator);
    }

    RDisplay.showImage=function(){
    var allImgs = document.querySelectorAll('img');
        for(var i = 0;i < allImgs.length; i++){
            var img = allImgs[i];
            if(!img.getAttribute('src') && img.getAttribute('data-src')){
                img.setAttribute('src',img.getAttribute('data-src'));
            }
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

    RDisplay.logDom = null;
    RDisplay.log = function(str){
        if(RDisplay.logDom == null){
            RDisplay.logDom = document.createElement('div');
            RDisplay.logDom.setAttribute('style','position:absolute;top:0;right:0;font-size:12px;border:1px solid #000;color:#000;padding:3px');
            document.getElementsByTagName('body')[0].appendChild(RDisplay.logDom);
        }
        RDisplay.logDom.innerHTML = RDisplay.logDom.innerHTML + "<br/>" + str;
    }
    </script>

    <script>
             window.onload=function(){
                wereadBridge.handleWithRichEditor("initFinish",{"param" : ""}, "", "");
             }

    </script>

