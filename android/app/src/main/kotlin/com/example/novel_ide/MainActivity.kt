package com.example.novel_ide

import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private val channelName = "com.example.novel_ide/tts"
    private var methodChannel: MethodChannel? = null
    private lateinit var audioManager: AudioManager
    private var isSpeakerOn = false // 默认关闭扬声器（走听筒/耳机）
    private var bluetoothHeadsetConnected = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        methodChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "initTTS" -> {
                    val locale = call.argument<String>("locale") ?: "zh-CN"
                    initTTS(locale, result)
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    speak(text, result)
                }
                "stop" -> {
                    tts?.stop()
                    result.success(null)
                }
                "setSpeechRate" -> {
                    val rate = call.argument<Double>("rate") ?: 1.0
                    tts?.setSpeechRate(rate.toFloat())
                    result.success(null)
                }
                "setPitch" -> {
                    val pitch = call.argument<Double>("pitch") ?: 1.0
                    tts?.setPitch(pitch.toFloat())
                    result.success(null)
                }
                "setLanguage" -> {
                    val locale = call.argument<String>("locale") ?: "zh-CN"
                    val javaLocale = java.util.Locale(locale)
                    val ttsResult = tts?.setLanguage(javaLocale)
                    result.success(ttsResult == TextToSpeech.LANG_AVAILABLE || ttsResult == TextToSpeech.LANG_COUNTRY_AVAILABLE)
                }
                "setSpeakerOn" -> {
                    val speakerOn = call.argument<Boolean>("speakerOn") ?: false
                    setSpeakerOn(speakerOn, result)
                }
                "isBluetoothConnected" -> {
                    result.success(bluetoothHeadsetConnected)
                }
                "shutdown" -> {
                    tts?.stop()
                    tts?.shutdown()
                    tts = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initTTS(locale: String, result: MethodChannel.Result) {
        if (tts != null) {
            tts?.stop()
            tts?.shutdown()
        }
        tts = TextToSpeech(this, TextToSpeech.OnInitListener { status ->
            if (status == TextToSpeech.SUCCESS) {
                val javaLocale = java.util.Locale(locale)
                tts?.language = javaLocale
                tts?.setSpeechRate(0.8f)
                // 设置音频属性为语音通话流
                tts?.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                // 监听朗读完成事件，通知 Flutter 端
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}
                    override fun onDone(utteranceId: String?) {
                        methodChannel?.invokeMethod("onSpeakingDone", null)
                    }
                    override fun onError(utteranceId: String?) {
                        methodChannel?.invokeMethod("onSpeakingDone", null)
                    }
                })
                // 初始化音频路由
                initAudioRoute()
                runOnUiThread { result.success(true) }
            } else {
                runOnUiThread { result.error("TTS_INIT_FAILED", "TTS初始化失败", null) }
            }
        })
    }

    private fun speak(text: String, result: MethodChannel.Result) {
        if (tts == null) {
            result.error("TTS_NOT_INIT", "TTS未初始化", null)
            return
        }
        // 每次朗读前确保音频路由正确
        applyAudioRoute()
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "novel_ide_tts")
        result.success(null)
    }

    /// 初始化音频路由：检测蓝牙/有线耳机状态
    private fun initAudioRoute() {
        bluetoothHeadsetConnected = isBluetoothHeadsetConnected()
        // 如果有蓝牙耳机连接，关闭扬声器走耳机
        if (bluetoothHeadsetConnected) {
            isSpeakerOn = false
            audioManager.isSpeakerphoneOn = false
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        } else if (isWiredHeadsetConnected()) {
            // 有线耳机连接，走耳机
            isSpeakerOn = false
            audioManager.isSpeakerphoneOn = false
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        } else {
            // 没有耳机，默认走听筒（MODE_IN_COMMUNICATION + speaker off）
            isSpeakerOn = false
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager.isSpeakerphoneOn = false
        }
    }

    /// 应用当前音频路由
    private fun applyAudioRoute() {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        if (isSpeakerOn) {
            // 开启扬声器：外放
            audioManager.isSpeakerphoneOn = true
        } else {
            // 关闭扬声器
            audioManager.isSpeakerphoneOn = false
        }
    }

    /// 设置扬声器开关（微信风格：点亮=外放，熄灭=默认输出）
    private fun setSpeakerOn(speakerOn: Boolean, result: MethodChannel.Result) {
        isSpeakerOn = speakerOn
        applyAudioRoute()
        result.success(isSpeakerOn)
    }

    /// 检测蓝牙耳机是否连接
    private fun isBluetoothHeadsetConnected(): Boolean {
        return try {
            val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val btAdapter = btManager?.adapter
            if (btAdapter == null || !btAdapter.isEnabled) return false

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val devices = btManager.getConnectedDevices(BluetoothProfile.HEADSET)
                devices.isNotEmpty()
            } else {
                @Suppress("DEPRECATION")
                val headset = btAdapter.getProfileConnectionState(BluetoothProfile.HEADSET)
                headset == BluetoothProfile.STATE_CONNECTED
            }
        } catch (e: Exception) {
            false
        }
    }

    /// 检测有线耳机是否连接
    private fun isWiredHeadsetConnected(): Boolean {
        return audioManager.isWiredHeadsetOn
    }

    override fun onDestroy() {
        super.onDestroy()
        tts?.stop()
        tts?.shutdown()
        audioManager.mode = AudioManager.MODE_NORMAL
    }
}
