import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Đăng nhập / đăng ký bằng tên đăng nhập + mật khẩu (tài khoản thành viên).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = context.read<AppState>();
    try {
      if (_register) {
        await app.register(_user.text, _pass.text, _confirm.text);
      } else {
        await app.login(_user.text, _pass.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [CxColors.emerald700, CxColors.emerald900], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Stack(children: [
                      const Positioned(right: -18, bottom: -24, child: Icon(Icons.eco_rounded, size: 150, color: Color(0x2619582F))),
                      const Positioned(right: 30, top: 18, child: Icon(Icons.local_florist_rounded, size: 44, color: Color(0x55F2C230))),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                          Container(
                            width: 46,
                            height: 46,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: Image.asset('assets/images/logo.png', semanticLabel: 'Logo Chạm Xanh'),
                          ),
                          const SizedBox(height: 10),
                          Text('Chạm Xanh', style: t.headlineMedium?.copyWith(color: Colors.white)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  Text(_register ? 'Tạo tài khoản miễn phí' : 'Chào mừng trở lại 👋', style: t.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    _register ? 'Chỉ cần tên đăng nhập và mật khẩu. Lưu vườn, đặt nhắc tưới và trò chuyện cùng cộng đồng.' : 'Vườn của bạn đang chờ. Tài khoản dùng chung với web Chạm Xanh.',
                    style: t.bodyLarge?.copyWith(color: CxColors.stone600),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _user,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: (v) {
                      final s = (v ?? '').trim().toLowerCase();
                      if (s.isEmpty) return 'Nhập tên đăng nhập';
                      if (_register && !RegExp(r'^[a-z0-9._]{4,30}$').hasMatch(s)) return '4–30 ký tự: chữ không dấu, số, dấu chấm hoặc gạch dưới';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pass,
                    obscureText: !_show,
                    autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                    textInputAction: _register ? TextInputAction.next : TextInputAction.done,
                    onFieldSubmitted: (_) => _register ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                        icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _show = !_show),
                      ),
                    ),
                    validator: (v) => (v ?? '').isEmpty ? 'Nhập mật khẩu' : _register && v!.length < 8 ? 'Mật khẩu ít nhất 8 ký tự' : null,
                  ),
                  if (_register) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirm,
                      obscureText: !_show,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_reset_rounded)),
                      validator: (v) => v != _pass.text ? 'Mật khẩu nhập lại chưa khớp' : null,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: const TextStyle(color: CxColors.danger)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(_register ? 'Tạo tài khoản' : 'Đăng nhập'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() {
                              _register = !_register;
                              _error = null;
                            }),
                    child: Text(_register ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký'),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    Text('Lần đầu máy chủ có thể mất vài chục giây để khởi động…', style: t.bodySmall, textAlign: TextAlign.center),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
