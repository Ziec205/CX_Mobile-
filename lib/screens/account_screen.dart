import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'reminder_sheet.dart';
import 'upgrade_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: CxColors.emerald700,
              child: Text((me?.displayName ?? '?').characters.first.toUpperCase(), style: t.headlineSmall?.copyWith(color: CxColors.wood400)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me?.displayName ?? '—', style: t.titleLarge),
                if (me?.username != null) Text('@${me!.username}', style: t.bodyMedium),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: CxColors.wood100,
            borderRadius: BorderRadius.circular(20),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              leading: const Icon(Icons.workspace_premium_rounded, color: CxColors.wood800),
              title: Text('Nâng cấp gói', style: t.titleMedium?.copyWith(color: CxColors.wood800)),
              subtitle: const Text('Lưu thêm cây, nhiều lượt AI, quét QR thanh toán'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen())),
            ),
          ),
        ),
        const SectionTitle('Liên lạc'),
        ListTile(
          leading: Badge(isLabelVisible: app.unreadChats > 0, label: Text('${app.unreadChats}'), child: const Icon(Icons.chat_bubble_outline_rounded)),
          title: const Text('Tin nhắn'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.alternate_email_rounded),
          title: const Text('Email nhận nhắc lịch'),
          subtitle: Text(me?.email ?? 'Chưa có'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            try {
              if (await askEmail(context) && context.mounted) showInfo(context, 'Đã lưu email');
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          },
        ),
        const SectionTitle('Nhắc tưới'),
        SwitchListTile(
          secondary: const Icon(Icons.alarm_rounded, color: CxColors.water500),
          title: const Text('Báo thức trên điện thoại'),
          subtitle: Text(app.lastSync == null ? 'Chưa đồng bộ' : 'Đồng bộ lúc ${vnDateTime(app.lastSync!)}'),
          value: app.remindersOnPhone,
          onChanged: app.setRemindersOnPhone,
        ),
        const SectionTitle('Khác'),
        ListTile(
          leading: const Icon(Icons.language_rounded),
          title: const Text('Mở Chạm Xanh trên web'),
          subtitle: const Text('Chợ cây, Trợ lý AI và các tính năng khác'),
          onTap: () => launchUrl(Uri.parse(AppConfig.webBase), mode: LaunchMode.externalApplication),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Ảnh cây lưu ở đâu?'),
          subtitle: Text('Trong app (thư mục "${AppConfig.photoAlbum}/<tên cây>") và album "${AppConfig.photoAlbum}" của Ảnh. Không tải lên máy chủ.'),
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: CxColors.danger),
          title: const Text('Đăng xuất', style: TextStyle(color: CxColors.danger)),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Đăng xuất?'),
                content: const Text('Lịch nhắc trên máy sẽ tắt. Ảnh cây vẫn giữ trên điện thoại.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất')),
                ],
              ),
            );
            if (ok == true) await app.logout();
          },
        ),
        Padding(padding: const EdgeInsets.all(16), child: Text('Máy chủ: ${app.api.baseUrl}', style: t.bodySmall, textAlign: TextAlign.center)),
      ]),
    );
  }
}
