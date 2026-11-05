import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Giới thiệu 3 bước khi mở app lần đầu: nói rõ lợi ích trước khi xin tài khoản/quyền.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _i = 0;

  static const _items = [
    (Icons.yard_rounded, CxColors.emerald700, CxColors.emerald50, 'Chăm vườn nhẹ nhàng', 'Lưu từng cây trong vườn của bạn. Ảnh chụp được giữ ngay trên điện thoại, không lo mất.'),
    (Icons.alarm_on_rounded, CxColors.water500, CxColors.water50, 'Không còn quên tưới', 'Đến giờ, điện thoại đổ chuông như báo thức. Bấm “Đã tưới” là xong, trên web cũng thấy ngay.'),
    (Icons.forum_rounded, CxColors.wood800, CxColors.wood100, 'Có bạn cùng chơi cây', 'Hỏi khi cây yếu, khoe chậu mới, nhắn tin mua bán cây với người cùng sở thích.'),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_i == _items.length - 1) {
      context.read<AppState>().completeOnboarding();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => context.read<AppState>().completeOnboarding(), child: const Text('Bỏ qua')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _items.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (_, i) {
                final (icon, fg, bg, title, body) = _items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                      child: Icon(icon, size: 96, color: fg),
                    ),
                    const SizedBox(height: 40),
                    Text(title, style: t.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(body, style: t.bodyLarge?.copyWith(color: CxColors.stone600), textAlign: TextAlign.center),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < _items.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: k == _i ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(color: k == _i ? CxColors.emerald700 : CxColors.stone200, borderRadius: BorderRadius.circular(8)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _next, child: Text(_i == _items.length - 1 ? 'Bắt đầu thôi' : 'Tiếp tục')),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Giải thích trước vì sao cần quyền thông báo, rồi mới để hệ thống hỏi (người dùng dễ đồng ý hơn).
Future<void> showNotificationPrimer(BuildContext context) async {
  final app = context.read<AppState>();
  final t = Theme.of(context).textTheme;
  final allow = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: CxColors.water50, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active_rounded, size: 44, color: CxColors.water500),
          ),
          const SizedBox(height: 16),
          Text('Để Chạm Xanh nhắc bạn tưới cây nhé?', style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text('Chúng tôi chỉ báo khi đến giờ chăm cây bạn đã đặt, không gửi quảng cáo.', style: t.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cho phép nhắc'))),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
        ]),
      ),
    ),
  );
  await app.markNotifPrimed();
  if (allow == true) await app.notifications.requestPermissions(exact: false);
}
