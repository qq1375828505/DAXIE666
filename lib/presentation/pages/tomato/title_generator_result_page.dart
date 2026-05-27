import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/presentation/widgets/top_notification.dart';

/// 标题生成结果页
class TitleGeneratorResultPage extends StatelessWidget {
  final String aiResponse;

  const TitleGeneratorResultPage({super.key, required this.aiResponse});

  @override
  Widget build(BuildContext context) {
    // Parse titles from AI response (split by newlines, filter numbered items)
    final lines = aiResponse.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('爆款标题生成')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.title, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text('生成结果', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  ...lines.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(line, style: const TextStyle(fontSize: 15, height: 1.5)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: line));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
