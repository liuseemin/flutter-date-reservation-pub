import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import '../models/request.dart'; // 或改成 Map

class SubmissionSuccessPage extends StatelessWidget {
  const SubmissionSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final req =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final dates = (req['dates'] as List).whereType<DateTime>();
    final dateStr = dates
        .map((d) => d.toIso8601String().split('T').first)
        .join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('已送出')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ 預假成功！', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Text('以下為您的資料：', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('姓名：${req['name']}'),
            Text('職級：${req['rank']}'),
            Text('員編：${req['employeeId']}'),
            Text('下月科別：${req['unit']}'),
            Text('預假日期：$dateStr'),
            Text('特殊需求：${req['note'].isEmpty ? '（無）' : req['note']}'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy_all),
              label: const Text('複製內容'),
              onPressed: () {
                final copyText =
                    "姓名：${req['name']}\n職級：${req['rank']}\n員編：${req['employeeId']}\n下月科別：${req['unit']}\n預假日期：$dateStr\n特殊需求：${req['note'].isEmpty ? '（無）' : req['note']}";
                Clipboard.setData(ClipboardData(text: copyText));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已複製到剪貼簿')));
              },
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('回首頁'),
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}
