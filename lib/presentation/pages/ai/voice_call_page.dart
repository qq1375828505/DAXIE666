import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/services/voice_service.dart';
import 'package:novel_ide/data/services/ai_service.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';

/// 语音通话页面 - 实时语音对话界面
class VoiceCallPage extends ConsumerStatefulWidget {
  /// 通话结束回调，返回通话记录文字
  final Function(String transcript, String aiResponse) onCallEnd;

  const VoiceCallPage({super.key, required this.onCallEnd});

  @override
  ConsumerState<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends ConsumerState<VoiceCallPage>
    with TickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  bool _isCallActive = false;
  bool _isInitialized = false;
  final List<String> _transcript = []; // 通话记录
  String _currentPartial = ''; // 当前正在识别的文字
  final Stopwatch _callTimer = Stopwatch();
  Timer? _displayTimer;
  String _callDuration = '00:00';
  double _waveAmplitude = 0.0;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _initVoice();
  }

  Future<void> _initVoice() async {
    final available = await _voiceService.init();
    if (mounted) {
      setState(() => _isInitialized = available);
      if (available) {
        _voiceService.onResult = (text) {
          setState(() => _currentPartial = text);
        };
        _voiceService.onListeningStart = () {
          setState(() => _waveAmplitude = 1.0);
        };
        _voiceService.onListeningEnd = () async {
          if (_currentPartial.isNotEmpty) {
            final userText = _currentPartial;
            setState(() {
              _transcript.add('👤 $userText');
              _currentPartial = '';
              _waveAmplitude = 0.0;
            });
            // 调用AI获取回复
            await _getAiResponse(userText);
          }
        };
        // 监听静音和扬声器状态变化
        _voiceService.onMutedChanged = (isMuted) {
          setState(() {});
        };
        _voiceService.onSpeakerChanged = (isSpeakerOn) {
          setState(() {});
        };
      }
    }
  }

  /// 获取AI回复
  Future<void> _getAiResponse(String userMessage) async {
    if (!_isCallActive) return;
    
    final aiConfig = ref.read(selectedAiConfigProvider);
    if (aiConfig == null) {
      setState(() {
        _transcript.add('🤖 错误：未配置AI模型，请在设置中添加');
      });
      return;
    }

    try {
      final aiService = AiService();
      final response = await aiService.send(
        config: aiConfig,
        systemPrompt: '你是一个友好的AI助手，正在进行语音对话。请用简洁自然的语言回复。',
        userMessage: userMessage,
      );
      await _aiRespond(response);
    } catch (e) {
      setState(() {
        _transcript.add('🤖 错误：$e');
      });
      // 出错后继续监听
      if (_isCallActive && !_voiceService.isMuted) {
        await _voiceService.startListening();
      }
    }
  }

  void _startCall() {
    setState(() {
      _isCallActive = true;
      _callTimer.start();
    });
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        final mins = (_callTimer.elapsed.inSeconds ~/ 60).toString().padLeft(2, '0');
        final secs = (_callTimer.elapsed.inSeconds % 60).toString().padLeft(2, '0');
        _callDuration = '$mins:$secs';
      });
    });
    _voiceService.startListening();
  }

  Future<void> _endCall() async {
    await _voiceService.stopListening();
    _voiceService.stopSpeaking();
    _displayTimer?.cancel();
    _callTimer.stop();

    // 构建通话记录
    final userText = _transcript.where((t) => t.startsWith('👤')).map((t) => t.substring(2)).join('\n');
    final aiText = _transcript.where((t) => t.startsWith('🤖')).map((t) => t.substring(2)).join('\n');

    if (mounted) {
      widget.onCallEnd(userText, aiText);
      Navigator.pop(context);
    }
  }

  /// AI回复（语音合成）
  Future<void> _aiRespond(String text) async {
    setState(() {
      _transcript.add('🤖 $text');
    });
    await _voiceService.speak(text);
    // 朗读完毕后继续监听
    await Future.delayed(const Duration(milliseconds: 500));
    if (_isCallActive) {
      await _voiceService.startListening();
    }
  }

  @override
  void dispose() {
    _voiceService.dispose();
    _displayTimer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部状态栏
            _buildStatusBar(),
            const Spacer(),
            // 波形动画
            _buildWaveAnimation(),
            const SizedBox(height: 40),
            // 通话记录
            _buildTranscript(),
            const Spacer(),
            // 底部控制按钮
            _buildControls(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isCallActive ? '通话中' : '语音通话',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Text(
                _isCallActive ? _callDuration : (_isInitialized ? '准备就绪' : '初始化中...'),
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveAnimation() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _WavePainter(
            amplitude: _waveAmplitude,
            progress: _waveController.value,
            color: _isCallActive ? AppColors.primary : Colors.grey,
          ),
        );
      },
    );
  }

  Widget _buildTranscript() {
    if (_transcript.isEmpty && _currentPartial.isEmpty) {
      return Text(
        _isCallActive ? '正在聆听...' : '点击下方按钮开始通话',
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _transcript.length + (_currentPartial.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _transcript.length) {
            final text = _transcript[index];
            final isUser = text.startsWith('👤');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.primary,
                  fontSize: 14,
                ),
                textAlign: isUser ? TextAlign.right : TextAlign.left,
              ),
            );
          }
          // 当前正在识别的文字
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '👤 $_currentPartial...',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              textAlign: TextAlign.right,
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        // 静音按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              icon: _voiceService.isMuted ? Icons.mic_off : Icons.mic,
              label: _voiceService.isMuted ? '已静音' : '静音',
              isActive: _voiceService.isMuted,
              onTap: () {
                _voiceService.toggleMute();
              },
            ),
            const SizedBox(width: 40),
            // 主按钮：开始/结束通话
            GestureDetector(
              onTap: _isCallActive ? _endCall : _startCall,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCallActive ? Colors.red : AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: (_isCallActive ? Colors.red : AppColors.primary).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isCallActive ? Icons.call_end : Icons.call,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 40),
            _ControlButton(
              icon: _voiceService.isSpeakerOn ? Icons.volume_up : Icons.headphones,
              label: _voiceService.isSpeakerOn ? '扬声器' : '耳机',
              isActive: _voiceService.isSpeakerOn,
              onTap: () {
                _voiceService.toggleSpeaker();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              border: isActive
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.primary : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.primary : Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// 波形绘制
class _WavePainter extends CustomPainter {
  final double amplitude;
  final double progress;
  final Color color;

  _WavePainter({required this.amplitude, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 10;

    // 绘制多层波纹
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * (0.3 + waveProgress * 0.7) * amplitude;
      final opacity = (1.0 - waveProgress) * 0.3 * amplitude;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }

    // 中心圆
    final centerPaint = Paint()
      ..color = color.withOpacity(0.2 * amplitude + 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 40, centerPaint);

    // 中心图标背景
    final iconPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 28, iconPaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.amplitude != amplitude || oldDelegate.progress != progress;
  }
}


