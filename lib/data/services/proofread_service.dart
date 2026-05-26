import 'dart:io';
import 'package:novel_ide/data/datasources/database_helper.dart';
import 'package:novel_ide/data/datasources/local_file_datasource.dart';
import 'package:path/path.dart' as p;

/// 校对结果条目
class ProofreadItem {
  final String type; // typo | punctuation | suggestion
  final String original; // 原文
  final String suggestion; // 建议修改
  final String context; // 上下文（前后各20字）
  final String chapterId;
  final String chapterTitle;
  final int position; // 在原文中的位置

  ProofreadItem({
    required this.type,
    required this.original,
    required this.suggestion,
    required this.context,
    required this.chapterId,
    required this.chapterTitle,
    required this.position,
  });

  String get typeLabel {
    switch (type) {
      case 'typo': return '错别字';
      case 'punctuation': return '标点符号';
      case 'suggestion': return '用词建议';
      default: return '其他';
    }
  }
}

/// 文章校对服务
/// 在 Dart 层实现中文常见的错别字检测和标点纠正
class ProofreadService {
  // ==================== 常见错别字词库 ====================
  // [错误写法, 正确写法]
  static const List<List<String>> _typoRules = [
    ['以经', '已经'],
    ['己经', '已经'],
    ['即然', '既然'],
    ['一剑钟情', '一见钟情'],
    ['莫明其妙', '莫名其妙'],
    ['豪不犹豫', '毫不犹豫'],
    ['不可思意', '不可思议'],
    ['心干情愿', '心甘情愿'],
    ['理所当燃', '理所当然'],
    ['迫不急待', '迫不及待'],
    ['迫不及特', '迫不及待'],
    ['迫不及带', '迫不及待'],
    ['兴高彩烈', '兴高采烈'],
    ['目瞪口带', '目瞪口呆'],
    ['意想天开', '异想天开'],
    ['晃然大悟', '恍然大悟'],
    ['目不转精', '目不转睛'],
    ['振耳欲聋', '震耳欲聋'],
    ['翻天复地', '翻天覆地'],
    ['不寒而立', '不寒而栗'],
    ['应接不遐', '应接不暇'],
    ['无动于中', '无动于衷'],
    ['一愁莫展', '一筹莫展'],
    ['穿流不息', '川流不息'],
    ['再接再励', '再接再厉'],
    ['走头无路', '走投无路'],
    ['莫明奇妙', '莫名其妙'],
    ['自抱自弃', '自暴自弃'],
    ['鬼鬼崇崇', '鬼鬼祟祟'],
    ['金壁辉煌', '金碧辉煌'],
    ['委屈求全', '委曲求全'],
    ['世外桃园', '世外桃源'],
    ['原形必露', '原形毕露'],
    ['破斧沉舟', '破釜沉舟'],
    ['默守成规', '墨守成规'],
    ['鼎立相助', '鼎力相助'],
    ['蛛丝蚂迹', '蛛丝马迹'],
    ['名幅其实', '名副其实'],
    ['相铺相成', '相辅相成'],
    ['相得益章', '相得益彰'],
    ['挺而走险', '铤而走险'],
    ['功亏一匮', '功亏一篑'],
    ['融汇贯通', '融会贯通'],
    ['悬梁刺骨', '悬梁刺股'],
    ['美仑美奂', '美轮美奂'],
    ['一股作气', '一鼓作气'],
    ['天翻地复', '天翻地覆'],
    ['换然一新', '焕然一新'],
    ['鞠躬尽粹', '鞠躬尽瘁'],
    ['沤心沥血', '呕心沥血'],
    ['按步就班', '按部就班'],
    ['谈笑风声', '谈笑风生'],
    ['声名雀起', '声名鹊起'],
    ['草管人命', '草菅人命'],
    ['娇揉造作', '矫揉造作'],
    ['萎糜不振', '萎靡不振'],
    ['如法泡制', '如法炮制'],
    ['仗义直言', '仗义执言'],
    ['惹事生非', '惹是生非'],
    ['唇枪舌战', '唇枪舌剑'],
    ['以逸代劳', '以逸待劳'],
    ['明查秋毫', '明察秋毫'],
    ['估名钓誉', '沽名钓誉'],
    ['励兵秣马', '厉兵秣马'],
  ];

  // ==================== 标点符号修正规则 ====================
  static const List<List<String>> _punctuationRules = [
    // [错误模式, 修正]
    ['。。', '……'],           // 两个句号改为省略号
    ['。。。', '……'],         // 三个句号改为省略号
    ['。。。。', '……'],       // 四个句号改为省略号
    ['！！！', '！'],          // 重复感叹号简化
    ['？？？', '？'],          // 重复问号简化
    ['，，', '，'],            // 重复逗号
    ['。。。。。。', '……'],   // 六个句号
    ['...…', '……'],           // 混合省略号
    ['………', '……'],           // 过多省略号
    [',,', '，'],              // 英文逗号
    ['..', '。'],              // 英文句号
    ['!!', '！'],              // 英文感叹号
    ['??', '？'],              // 英文问号
  ];

  // ==================== 中英文标点混用检测 ====================
  static final RegExp _mixedPunctuation = RegExp(r'[一-鿿][,.!?;:)]');
  static final RegExp _englishPuncAfterChinese = RegExp(r'[一-鿿][\x21-\x2f\x3a-\x40\x5b-\x60\x7b-\x7e]');

  /// 校对单个文本
  List<ProofreadItem> proofreadText(String text, String chapterId, String chapterTitle) {
    final results = <ProofreadItem>[];

    // 1. 错别字检测
    for (final rule in _typoRules) {
      final wrongWord = rule[0];
      final correctWord = rule[1];
      int start = 0;
      while (true) {
        final idx = text.indexOf(wrongWord, start);
        if (idx == -1) break;

        final contextStart = (idx - 20).clamp(0, text.length);
        final contextEnd = (idx + wrongWord.length + 20).clamp(0, text.length);

        results.add(ProofreadItem(
          type: 'typo',
          original: wrongWord,
          suggestion: correctWord,
          context: text.substring(contextStart, contextEnd),
          chapterId: chapterId,
          chapterTitle: chapterTitle,
          position: idx,
        ));
        start = idx + 1;
      }
    }

    // 2. 标点符号修正
    for (final rule in _punctuationRules) {
      int start = 0;
      while (true) {
        final idx = text.indexOf(rule[0], start);
        if (idx == -1) break;

        final contextStart = (idx - 20).clamp(0, text.length);
        final contextEnd = (idx + rule[0].length + 20).clamp(0, text.length);

        results.add(ProofreadItem(
          type: 'punctuation',
          original: rule[0],
          suggestion: rule[1],
          context: text.substring(contextStart, contextEnd),
          chapterId: chapterId,
          chapterTitle: chapterTitle,
          position: idx,
        ));
        start = idx + 1;
      }
    }

    // 3. 中英文标点混用
    for (final match in _mixedPunctuation.allMatches(text)) {
      final pos = match.start;
      final contextStart = (pos - 20).clamp(0, text.length);
      final contextEnd = (match.end + 20).clamp(0, text.length);

      results.add(ProofreadItem(
        type: 'punctuation',
        original: match.group(0)!,
        suggestion: '中文后应使用中文标点',
        context: text.substring(contextStart, contextEnd),
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        position: pos,
      ));
    }

    // 4. 重复词语检测（如"的的"、"了了"）
    final repeatedWordPattern = RegExp(r'([一-鿿])\1{2,}');
    for (final match in repeatedWordPattern.allMatches(text)) {
      final pos = match.start;
      final contextStart = (pos - 20).clamp(0, text.length);
      final contextEnd = (match.end + 20).clamp(0, text.length);

      results.add(ProofreadItem(
        type: 'suggestion',
        original: match.group(0)!,
        suggestion: '疑似重复用字',
        context: text.substring(contextStart, contextEnd),
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        position: pos,
      ));
    }

    // 按位置排序
    results.sort((a, b) => a.position.compareTo(b.position));
    return results;
  }

  /// 校对整个作品的所有章节
  Future<List<ProofreadItem>> proofreadNovel(String novelId) async {
    final db = await DatabaseHelper().database;
    final fs = LocalFileDataSource();
    final projectPath = await fs.getProjectDir(novelId, '');

    final chapterRows = await db.query('chapters',
        where: 'novel_id = ?', whereArgs: [novelId], orderBy: 'order_index ASC');

    final allResults = <ProofreadItem>[];

    for (final row in chapterRows) {
      final chapterId = row['id'] as String;
      final chapterTitle = row['title'] as String;
      final contentFile = File(p.join(projectPath, 'chapters', '$chapterId.md'));

      if (await contentFile.exists()) {
        final content = await contentFile.readAsString();
        final results = proofreadText(content, chapterId, chapterTitle);
        allResults.addAll(results);
      }
    }

    return allResults;
  }
}
