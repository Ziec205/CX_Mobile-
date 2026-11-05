import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'reminder_sheet.dart';
import 'upgrade_screen.dart';

/// Ảnh đại diện trên thanh trên cùng: bấm để mở phần tài khoản rút gọn.
class AccountAction extends StatelessWidget {
  const AccountAction({super.key});
  @override
  Widget build(BuildContext context) {
    final name = context.select<AppState, String>((a) {
      final n = a.me?.displayName ?? '';
      return n.isEmpty ? '?' : n;
    });
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: 'Tài khoản',
        padding: EdgeInsets.zero,
        icon: CircleAvatar(
          radius: 18,
          backgroundColor: CxColors.wood400,
          child: Text(name.characters.first.toUpperCase(), style: const TextStyle(color: CxColors.stone900, fontWeight: FontWeight.w700)),
        ),
        onPressed: () => showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (_) => const _AccountSheet()),
      ),
    );
  }
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(me?.displayName ?? '—', style: t.titleLarge),
            subtitle: me?.username == null ? null : Text('@${me!.username}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.workspace_premium_rounded, color: CxColors.wood800),
            title: const Text('Nâng cấp gói'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.alternate_email_rounded),
            title: const Text('Email nhận nhắc lịch'),
            subtitle: Text(me?.email ?? 'Chưa có'),
            onTap: () async {
              try {
                if (await askEmail(context) && context.mounted) showInfo(context, 'Đã lưu email');
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_rounded, color: CxColors.water500),
            title: const Text('Báo thức nhắc tưới'),
            value: app.remindersOnPhone,
            onChanged: app.setRemindersOnPhone,
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
              if (ok == true) {
                if (context.mounted) Navigator.pop(context);
                await app.logout();
              }
            },
          ),
        ]),
      ),
    );
  }
}
