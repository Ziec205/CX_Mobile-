import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Nâng cấp gói: chọn gói → BE tạo đơn PayOS → hiện mã VietQR ngay trong app → tự kiểm tra tới khi tiền về.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});
  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  int _months = 1;
  String? _busy;

  Future<(List<PlanInfo>, MyPlan?)> _load() async {
    final api = context.read<AppState>().api;
    final res = await api.get('plans') as Map<String, dynamic>;
    final plans = (res['plans'] as List).cast<Map<String, dynamic>>().map(PlanInfo.fromJson).toList();
    MyPlan? mine;
    try {
      mine = MyPlan.fromJson(await api.get('me/plan') as Map<String, dynamic>);
    } catch (_) {}
    return (plans, mine);
  }

  Future<void> _buy(PlanInfo p) async {
    setState(() => _busy = p.code);
    try {
      final pay = PlanPayment.fromJson(await context.read<AppState>().api.post('plans/checkout', {'plan': p.code, 'months': _months, 'returnOrigin': AppConfig.webBase}) as Map<String, dynamic>);
      if (!mounted) return;
      final paid = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PaymentScreen(payment: pay, planName: p.name)));
      if (paid == true && mounted) setState(() {});
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nâng cấp gói')),
      body: LoadView<(List<PlanInfo>, MyPlan?)>(
        key: ValueKey(_busy == null),
        load: _load,
        builder: (context, data, reload) {
          final (plans, mine) = data;
          final current = mine?.plan.code ?? 'Free';
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              if (mine != null && current != 'Free')
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: CxColors.emerald50, borderRadius: BorderRadius.circular(16), border: Border.all(color: CxColors.emerald200)),
                  child: Text('Bạn đang dùng ${mine.plan.name}${mine.endAt != null ? ' đến ${vnDate(mine.endAt!)}' : ''}', style: t.titleMedium?.copyWith(color: CxColors.emerald900)),
                ),
              Center(
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [ButtonSegment(value: 1, label: Text('Theo tháng')), ButtonSegment(value: 12, label: Text('Theo năm · tặng 2 tháng'))],
                  selected: {_months},
                  onSelectionChanged: (s) => setState(() => _months = s.first),
                ),
              ),
              const SizedBox(height: 16),
              for (final p in plans) _PlanCard(plan: p, months: _months, current: current, busy: _busy == p.code, onBuy: _busy == null ? () => _buy(p) : null),
              const SizedBox(height: 8),
              Text('Thanh toán qua PayOS: quét VietQR bằng app ngân hàng bất kỳ. Gói kích hoạt ngay khi tiền về, không tự gia hạn.', style: t.bodySmall, textAlign: TextAlign.center),
            ]),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.months, required this.current, required this.busy, this.onBuy});
  final PlanInfo plan;
  final int months;
  final String current;
  final bool busy;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pro = plan.code == 'Pro';
    final price = months == 12 ? plan.yearlyVnd : plan.monthlyVnd;
    final fg = pro ? Colors.white : CxColors.stone900;
    final isCurrent = current == plan.code;
    final lower = current == 'Pro' && plan.code == 'Plus';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pro ? CxColors.emerald900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: pro ? null : Border.all(color: CxColors.stone200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(plan.name, style: t.headlineSmall?.copyWith(color: pro ? Colors.white : CxColors.emerald900))),
          if (pro) const Pill('Cho người bán nhiều', bg: CxColors.wood400, fg: CxColors.stone900),
        ]),
        const SizedBox(height: 4),
        Text(plan.tagline, style: t.bodyMedium?.copyWith(color: pro ? CxColors.emerald100 : CxColors.stone600)),
        const SizedBox(height: 12),
        Text.rich(TextSpan(children: [
          TextSpan(text: price == 0 ? '0 đ' : vnd(price), style: t.headlineMedium?.copyWith(color: fg)),
          if (price > 0) TextSpan(text: months == 12 ? ' / năm' : ' / tháng', style: t.bodyMedium?.copyWith(color: pro ? CxColors.emerald200 : CxColors.stone500)),
        ])),
        const SizedBox(height: 12),
        for (final f in [
          'Hồ sơ vườn: ${plan.gardenPlants} cây',
          '${plan.aiPerDay} lượt Trợ lý AI mỗi ngày',
          '${plan.listingsPerMonth} tin đăng mỗi tháng',
          'Nhắc tưới, bón phân như báo thức',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.check_rounded, size: 20, color: pro ? CxColors.wood400 : CxColors.emerald600),
              const SizedBox(width: 8),
              Expanded(child: Text(f, style: t.bodyMedium?.copyWith(color: fg))),
            ]),
          ),
        const SizedBox(height: 10),
        if (plan.code == 'Free')
          Center(child: Text(isCurrent ? 'Gói hiện tại' : 'Luôn miễn phí', style: t.labelLarge?.copyWith(color: CxColors.stone500)))
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: pro ? CxColors.wood400 : CxColors.emerald700, foregroundColor: pro ? CxColors.stone900 : Colors.white),
              onPressed: lower ? null : onBuy,
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(lower ? 'Đang dùng gói cao hơn' : isCurrent ? 'Gia hạn $months tháng' : 'Mua ${plan.name}'),
            ),
          ),
      ]),
    );
  }
}

/// Màn hình quét mã: hiện VietQR từ BE, kiểm tra trạng thái mỗi 3 giây.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.payment, required this.planName});
  final PlanPayment payment;
  final String planName;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late PlanPayment _p = widget.payment;
  Timer? _timer;

  bool get _simulator => _p.checkoutUrl?.contains('/goi/gia-lap') == true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (!_p.isPending) return;
    try {
      final p = PlanPayment.fromJson(await context.read<AppState>().api.get('plans/payments/${_p.id}') as Map<String, dynamic>);
      if (!mounted) return;
      setState(() => _p = p);
      if (!p.isPending) _timer?.cancel();
    } catch (_) {}
  }

  Future<void> _simulate() async {
    try {
      await context.read<AppState>().api.post('plans/payments/${_p.id}/simulate');
      await _poll();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _saveQr() async {
    final qr = _p.qrCode;
    if (qr == null) return;
    try {
      const size = 900.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = Colors.white);
      canvas.translate(60, 60);
      QrPainter(data: qr, version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.M).paint(canvas, const Size(size - 120, size - 120));
      final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (!await Gal.hasAccess(toAlbum: true)) await Gal.requestAccess(toAlbum: true);
      await Gal.putImageBytes(bytes!.buffer.asUint8List(), album: AppConfig.photoAlbum, name: 'ChamXanh_QR_${_p.orderCode}');
      if (mounted) showInfo(context, 'Đã lưu mã QR vào Ảnh. Mở app ngân hàng → Quét QR → chọn ảnh.');
    } catch (e) {
      if (mounted) showInfo(context, 'Không lưu được ảnh: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final paid = _p.status == 'Paid';
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(paid ? 'Thanh toán thành công 🎉' : 'Quét mã để thanh toán', style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('${widget.planName} · ${_p.months} tháng · ${vnd(_p.amountVnd)}', style: t.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        if (paid)
          const EmptyState(icon: Icons.verified_rounded, title: 'Gói đã được kích hoạt', message: 'Cảm ơn bạn đã ủng hộ Chạm Xanh!')
        else ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: CxColors.stone200)),
              child: _p.qrCode == null
                  ? const SizedBox(width: 240, height: 240, child: Center(child: Text('Cổng thanh toán không trả mã QR.\nDùng nút "Mở trang PayOS" bên dưới.', textAlign: TextAlign.center)))
                  : QrImageView(
                      data: _p.qrCode!,
                      size: 260,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: CxColors.emerald900),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: CxColors.emerald900),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_p.isPending) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_p.isPending ? 'Đang chờ tiền về… (hết hạn ${vnDateTime(_p.expiresAt)})' : 'Đơn đã hết hạn hoặc bị hủy',
                  style: t.bodyMedium, textAlign: TextAlign.center),
            ),
          ]),
          const SizedBox(height: 20),
          if (_p.qrCode != null) OutlinedButton.icon(onPressed: _saveQr, icon: const Icon(Icons.download_rounded), label: const Text('Lưu mã QR vào Ảnh')),
          const SizedBox(height: 10),
          if (_p.checkoutUrl != null && !_simulator)
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(_p.checkoutUrl!), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Mở trang PayOS'),
            ),
          if (_simulator && _p.isPending) ...[
            const SizedBox(height: 10),
            FilledButton(onPressed: _simulate, child: const Text('Xác nhận thanh toán thử (máy chủ đang giả lập)')),
          ],
          const SizedBox(height: 16),
          Text('Mẹo: điện thoại không tự quét được màn hình của chính nó. Hãy lưu mã QR vào Ảnh rồi chọn ảnh trong mục Quét QR của app ngân hàng.', style: t.bodySmall, textAlign: TextAlign.center),
        ],
        if (paid) FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xong')),
      ]),
    );
  }
}
