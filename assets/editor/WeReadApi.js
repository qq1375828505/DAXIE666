(function() {
    WeReadBridge = function()  {
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


    WeReadBridge.prototype.fetchQueue = function() {
        var messageQueueString = JSON.stringify(this._sendMessageQueue);
        this._sendMessageQueue = [];
        this._setResultValue('fetchqueue', messageQueueString);
        return messageQueueString;
    }


    WeReadBridge.prototype._setResultValue = function(scene, result)  {
        // Android 通过另一个iframe上传数据
        if (result === undefined) {
            result = '';
        }
        this._resultIframe.src = this._resultIframe._SET_RESULT_URL + scene + '&' + this._base64Encode(this._utf8Encode(result));
    }
     // public method for url encoding
    WeReadBridge.prototype._utf8Encode = function(str) {
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

    WeReadBridge.prototype._base64Encode = function(str) {
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



    WeReadBridge.prototype._sendMessage = function(message) {
        this._sendMessageQueue.push(message);
        this._iframe.src = this._QUEUE_HAS_MESSAGE_URL;
    }

    WeReadBridge.prototype.handleMessage = function(message){
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

    WeReadBridge.prototype._call = function(func, params, callback)  {
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

    WeReadBridge.prototype.onReady = function(func)  {
        !_isReady && _bindReadyFuns.unshift([this, func]);
    }
    WeReadBridge.prototype.bindReady = function(func) {
        !_isReady ? _bindReadyFuns.unshift([this, func]) : func.call(this);
    }
    WeReadBridge.prototype.isReady = function()  {
        return _isReady;
    }
    WeReadBridge.prototype.isAvailable = function(apiName)  {
        return !!(_WeReadBridgeInfo && _WeReadBridgeInfo["apis"][apiName]);
    }
     var _isReady, _WeReadBridgeInfo, _bindReadyFuns = [],
         _onReady = function()  {
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
         window["__WRB_INFO_CALL__"] = function()  {
             _onReady();
         };
     }
})();

// /** 函数模板
//     * func_name description
//     * @param successCallback(result) result["param_name"]
//     * @param failCallback(result)   result["param_name"]
//     */
//     WeReadBridge.prototype.func_name = function(params, successCallback, failCallback) {
//         var self = this;
//         this._call("func_name", params, function(successOrNot, result) {
//             var params = {"func_name":result};
//             self.localLog(params);
//             if (successOrNot) {
//                    successCallback(result);
//             } else {
//                    failCallback(result);
//             }
//         });
//     }

// window.wereadBridge = new WeReadBridge();
// window.wereadBridge.goToUrl("http://wecall.qq.com/");//weread://bookDetail?opentype=0&bookId=414048");
/**
    load页面之前需要先执行以下的js
    eval('window["__QMB_INFO__"]={apis:{"a":1,"b":1},ver:"4.0.5",os:"android"};window["__QMB_INFO_CALL__"]&&window["__QMB_INFO_CALL__"]();');
*/

// window.wereadBridge.moreOperation(new Array({'shareToWechatTimeLine': {'title':'title','imageUrl':'imageUrl','abstract':'abstract','url':'url'}}));

// window.wereadBridge.shareToWechatFriend({'title':'中文','imageUrl':'imageUrl','abstract':'中文测试','url':'url'}, function(){}, function(){});
 // window.wereadBridge.shareToWechatTimeline({'title':'中文','imageUrl':'imageUrl','abstract':'中文测试','url':'url'}, function(){}, function(){});

// window.wereadBridge.getAppInfo(function(result){alert('getAppInfo: onSucc:'+JSON.stringify(result));}, function(result){alert('getAppInfo: onFailed:'+JSON.stringify(result));});

 // window.wereadBridge.closeBrowser();
 // window.wereadBridge.window.wereadBridge.mobileSync(function(error,result) {alert('error:' + error+"\n"+'result:' + result);});;
 // window.wereadBridge.window.wereadBridge.refreshToken(function(error,result) {alert('error:' + error+"\n"+'result:' + result);});;
 // window.wereadBridge.showBrowserMoreButton({'shareToWechatFriend':0, 'shareToWechatTimeline':1, 'copyLink':0, 'openLinkWithBrowser':0});
