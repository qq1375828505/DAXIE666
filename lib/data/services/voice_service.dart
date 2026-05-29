import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 语音服务 - 封装语音识别和语音合成
/// 语音合成使用 Android 原生 TTS（通过 MethodChannel），避免 flutter_tts 的 Kotlin 兼容问题
class VoiceService {
  static const _channel = MethodChannel('com.example.novel_ide/tts');

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _speechAvailable = false;
  bool _isMuted = false; // 静音状态
  bool _isSpeakerOn = false; // 扬声器状态，默认关闭（走听筒/耳机）
  String _lastWords = '';
  String _localeId = 'zh_CN';

  // 回调
  VoidCallback? onListeningStart;
  VoidCallback? onListeningEnd;
  ValueChanged<String>? onResult;
  ValueChanged<bool>? onSpeakingChanged;
  ValueChanged<bool>? onMutedChanged;
  ValueChanged<bool>? onSpeakerChanged;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isAvailable => _speechAvailable;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  String get lastWords => _lastWords;

  /// 初始化语音服务
  Future<bool> init() async {
    // 初始化语音识别
    _speechAvailable = await _speech.initialize(
      onError: (error) => debugPrint('语音识别错误: ${error.errorMsg}'),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          onListeningEnd?.call();
        }
      },
    );

    // 初始化原生 TTS
    try {
      await _channel.invokeMethod('initTTS', {'locale': _localeId});
      // 监听原生端朗读完成事件
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onSpeakingDone') {
          _isSpeaking = false;
          onSpeakingChanged?.call(false);
          onSpeakingDone?.call();
        }
      });
    } catch (e) {
      debugPrint('TTS初始化失败: $e');
    }

    return _speechAvailable;
  }

  /// 开始语音识别
  Future<void> startListening() async {
    if (!_speechAvailable) {
      await init();
      if (!_speechAvailable) return;
    }

    _isListening = true;
    onListeningStart?.call();

    await _speech.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        onResult?.call(_lastWords);
      },
      localeId: _localeId,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
    );
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('语音识别停止异常: $e');
    }
    _isListening = false;
    onListeningEnd?.call();
  }

  /// 切换语音识别状态
  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// 语音合成 - 朗读文字（通过原生 TTS），等待朗读完成
  Future<void> speak(String text) async {
    if (_isSpeaking) {
      await stopSpeaking();
    }
    _isSpeaking = true;
    onSpeakingChanged?.call(true);
    try {
      await _channel.invokeMethod('speak', {'text': text});
      // 等待原生端通知朗读完成
      // 原生 TTS 的 UtteranceProgressListener 会在朗读完毕后通过 channel 回调
    } catch (e) {
      debugPrint('TTS朗读失败: $e');
    }
    // 注意：_isSpeaking 的重置由原生端通过 onSpeakingDone 回调处理
  }

  /// 原生端朗读完成回调（由外部设置）
  VoidCallback? onSpeakingDone;

  /// 停止朗读
  Future<void> stopSpeaking() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('TTS停止失败: $e');
    }
    _isSpeaking = false;
    onSpeakingChanged?.call(false);
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    try {
      await _channel.invokeMethod('setSpeechRate', {'rate': rate});
    } catch (e) {
      debugPrint('设置语速失败: $e');
    }
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    try {
      await _channel.invokeMethod('setPitch', {'pitch': pitch});
    } catch (e) {
      debugPrint('设置音调失败: $e');
    }
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    _localeId = language;
    try {
      await _channel.invokeMethod('setLanguage', {'locale': language});
    } catch (e) {
      debugPrint('设置语言失败: $e');
    }
  }

  /// 切换静音状态
  void toggleMute() {
    _isMuted = !_isMuted;
    onMutedChanged?.call(_isMuted);
    if (_isMuted && _isListening) {
      stopListening();
    }
  }

  /// 切换扬声器状态
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    onSpeakerChanged?.call(_isSpeakerOn);
    try {
      await _channel.invokeMethod('setSpeakerOn', {'speakerOn': _isSpeakerOn});
    } catch (e) {
      debugPrint('切换扬声器失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _speech.stop();
    try {
      _channel.invokeMethod('shutdown');
    } catch (_) {}
  }
}
