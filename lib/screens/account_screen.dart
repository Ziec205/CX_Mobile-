import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'reminder_sheet.dart';
import 'upgrade_screen.dart';

/// Ảnh đại diện trên thanh trên cùng: bấm để mở phần tài khoản rút gọn.
/// Giống PlanAvatar của web: Plus viền xanh lá, Pro viền vàng ánh kim, kèm nhãn.
class PlanAvatar extends StatelessWidget {
  const PlanAvatar({super.key, required this.name, this.plan, this.radius = 18});
  final String name;
  final String? plan;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final face = CircleAvatar(
      radius: radius,
      backgroundColor: CxColors.wood400,
      child: name.isEmpty
          ? const Icon(Icons.person_outline_rounded, color: CxColors.stone900)
          : Text(name.characters.first.toUpperCase(), style: const TextStyle(color: CxColors.stone900, fontWeight: FontWeight.w700)),
    );
    final pro = plan == 'Pro';
    if (!pro && plan != 'Plus') return face;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pro ? null : CxColors.emerald600,
          gradient: pro ? const SweepGradient(colors: [Color(0xFFF6D365), Color(0xFFC8962E), Color(0xFFFFF1B8), Color(0xFFE0A526), Color(0xFFF6D365)]) : null,
        ),
        child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: face),
      ),
      Positioned(
        bottom: -4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(color: pro ? CxColors.stone900 : CxColors.emerald700, borderRadius: BorderRadius.circular(999)),
          child: Text(pro ? 'PRO' : 'PLUS', style: TextStyle(fontSize: 9, height: 1.5, fontWeight: FontWeight.w800, color: pro ? CxColors.wood400 : Colors.white)),
        ),
      ),
    ]);
  }
}

class AccountAction extends StatelessWidget {
  const AccountAction({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: 'Tài khoản',
        padding: EdgeInsets.zero,
        icon: PlanAvatar(name: app.me?.displayName ?? '', plan: app.plan?.plan.code),
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
            leading: PlanAvatar(name: me?.displayName ?? '', plan: app.plan?.plan.code, radius: 22),
            title: Text(me?.displayName ?? '—', style: t.titleLarge),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (me?.username != null) Text('@${me!.username}'),
              if (app.plan != null) Text('Gói ${app.plan!.plan.name}', style: const TextStyle(fontWeight: FontWeight.w600, color: CxColors.emerald700)),
            ]),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.workspace_premium_rounded, color: CxColors.wood800),
            title: const Text('Nâng cấp gói'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen()));
              await app.refreshPlan();
            },
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
