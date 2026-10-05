import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/baid_ui.dart';
import '../../../account_type/domain/account_type.dart';
import '../../../account_type/domain/role_categories.dart';
import '../../data/remembered_accounts.dart';
import '../../domain/auth_repository.dart';

/// Where the flow opens.
enum AuthStart { type, signIn, reset, onboard }

enum _View { entry, choose, type, signin, phone, code, name, cat, pass }

/// Sign-in and sign-up, built to match the website's auth.html view for view:
/// choose type → phone → code → name → category → password, plus the
/// "Welcome back" sign-in, password reset by phone, and account setup for
/// signed-in members who have no account type yet.
class AuthFlowScreen extends ConsumerStatefulWidget {
  const AuthFlowScreen({this.start = AuthStart.type, this.presetType, this.group, super.key});

  final AuthStart start;
  final AccountType? presetType;

  /// "pro" (professionals, project managers, suppliers) or "client" (home
  /// clients, companies), like auth.html?group=..; null shows every type.
  final String? group;

  @override
  ConsumerState<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends ConsumerState<AuthFlowScreen> {
  static const _flows = {
    'signup': [_View.phone, _View.code, _View.name, _View.cat, _View.pass],
    'onboard': [_View.name, _View.cat],
    'reset': [_View.phone, _View.code, _View.pass],
  };

  late String _mode;
  late List<_View> _history;
  AccountType _role = AccountType.worker;
  RoleCategory? _cat;
  var _usePhone = true;
  var _busy = false;
  var _showPw = false;
  String? _error;
  var _otpState = _OtpState.idle;
  // signing in from a guest page: the type is chosen first and checked after sign-in
  var _intent = false;
  // "pro" or "client" from the link, or picked on the entry screen
  String? _group;
  // the side picked on the entry screen; a sign-in from there must match it
  String? _gate;
  String? _welcome;
  List<RememberedAccount> _accs = const [];
  int _resendLeft = 0;
  Timer? _resendTimer;

  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _siPhone = TextEditingController();
  final _siPass = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _catQ = TextEditingController();
  final _codeFocus = FocusNode();

  _View get _view => _history.last;

  static const _groups = {
    'pro': ([AccountType.worker, AccountType.projectManager, AccountType.business], 'Join as a professional', 'Pick how you work on BAID X.', 'Professional sign-in'),
    'client': ([AccountType.employer, AccountType.company], 'Join to hire', 'Hiring for your home, or for your company?', 'Client sign-in'),
  };

  List<AccountType> get _roles => _groups[_group]?.$1 ?? AccountType.pickerOrder;

  RememberedAccounts get _remembered => RememberedAccounts(ref.read(keyValueStoreProvider));

  /// Accounts used on this device open the website's "Continue with" list first.
  Future<void> _loadAccounts() async {
    final accs = await _remembered.list();
    if (!mounted || accs.isEmpty || _history.length != 1 || (_view != _View.type && _view != _View.entry)) return;
    setState(() {
      _accs = accs;
      _history = [_View.choose];
    });
  }

  void _pickAccount(RememberedAccount a) {
    final local = a.phone.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^233'), '');
    setState(() {
      _intent = false;
      _mode = 'signin';
      _usePhone = true;
      _siPhone.text = local.isEmpty ? '' : '0$local';
      _siPass.clear();
      _welcome = 'Welcome back, ${a.name}. Enter your password to continue.';
    });
    _go(_View.signin);
  }

  Future<void> _rememberMe() async {
    final me = await _auth.loadProfile();
    final type = me?.type;
    if (me == null || type == null) return;
    final (photoCol, _, _) = switch (type) {
      AccountType.company => ('company_logo_url', '', ''),
      AccountType.business => ('logo_url', '', ''),
      _ => ('profile_photo_url', '', ''),
    };
    await _remembered.remember(RememberedAccount(id: me.id, name: me.displayName.isEmpty ? type.label : me.displayName, role: type.dbValue, phone: me.phone, photo: me.row[photoCol] as String?));
  }

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _role = widget.presetType ?? _roles.first;
    switch (widget.start) {
      // with no group in the link, both open on the professional / client entry
      case AuthStart.type:
        _mode = 'signup';
        _history = [_group == null ? _View.entry : _View.type];
        if (_group == null) _loadAccounts();
      case AuthStart.signIn:
        _mode = 'signin';
        _intent = _group != null;
        _history = [_group == null ? _View.entry : _View.type];
        _loadAccounts();
      case AuthStart.reset:
        _mode = 'reset';
        _history = [_View.phone];
      case AuthStart.onboard:
        _mode = 'onboard';
        _history = widget.presetType != null ? [_View.name] : [_View.type];
    }
    for (final c in [_phone, _code, _name, _pass, _siPhone, _siPass, _email, _catQ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in [_phone, _email, _siPhone, _siPass, _code, _name, _pass, _catQ]) {
      c.dispose();
    }
    _codeFocus.dispose();
    super.dispose();
  }

  void _go(_View v) => setState(() {
        _error = null;
        _history = [..._history, v];
        if (v == _View.code) Future.delayed(const Duration(milliseconds: 320), () => _codeFocus.requestFocus());
      });

  void _back() {
    if (_history.length <= 1) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.discover);
      }
      return;
    }
    setState(() {
      _error = null;
      _history = _history.sublist(0, _history.length - 1);
      if (_view == _View.type && _mode != 'onboard') _mode = _intent ? 'signin' : 'signup';
      if (_view != _View.signin) _welcome = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorHandler.toAppException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  // ---------- actions ----------
  Future<void> _sendCode() => _run(() async {
        await _auth.startPhoneCode(phone: _phone.text.trim(), purpose: _mode == 'reset' ? PhoneCodePurpose.reset : PhoneCodePurpose.signup);
        _code.clear();
        _startResend();
        if (_view != _View.code) _go(_View.code);
      });

  void _startResend() {
    _resendTimer?.cancel();
    setState(() => _resendLeft = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendLeft = (_resendLeft - 1).clamp(0, 99));
      if (_resendLeft == 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_code.text.length < 6 || _otpState == _OtpState.checking) return;
    setState(() {
      _otpState = _OtpState.checking;
      _error = null;
    });
    try {
      await _auth.verifyPhoneCode(phone: _phone.text.trim(), code: _code.text);
      ref.read(pendingPhoneProvider.notifier).set(_phone.text.trim());
      HapticFeedback.mediumImpact();
      setState(() => _otpState = _OtpState.ok);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (!mounted) return;
      setState(() => _otpState = _OtpState.idle);
      _go(_mode == 'reset' ? _View.pass : _View.name);
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _otpState = _OtpState.bad;
        _error = e is AppException ? e.message : 'That code isn\'t right.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      _code.clear();
      setState(() => _otpState = _OtpState.idle);
      _codeFocus.requestFocus();
    }
  }

  Future<void> _signIn() => _run(() async {
        if (_usePhone) {
          final bad = Validators.ghanaPhone(_siPhone.text);
          if (bad != null) throw AuthFlowException(bad);
          if (_siPass.text.isEmpty) throw const AuthFlowException('Enter your password.');
          await _auth.signInWithPhone(phone: _siPhone.text.trim(), password: _siPass.text);
        } else {
          final bad = Validators.email(_email.text);
          if (bad != null) throw const AuthFlowException('Enter a valid email address.');
          if (_siPass.text.isEmpty) throw const AuthFlowException('Enter your password.');
          await _auth.signInWithEmail(email: _email.text.trim(), password: _siPass.text);
        }
        ref.invalidate(accountProfileProvider);
        final me = await _auth.loadProfile();
        if (!mounted) return;
        final type = me?.type;
        // they chose an account type first, so make sure the account really is that type
        if (_intent && type != null && type != _role) {
          await _auth.signOut();
          throw AuthFlowException('That account is a ${type.label} account. Go back and choose ${type.label}.');
        }
        // signed in from the professional or client panel: the account has to belong to that side
        if (_gate != null && type != null && !_groups[_gate]!.$1.contains(type)) {
          await _auth.signOut();
          throw AuthFlowException('That is a ${type.label} account. Go back and use ${_gate == 'pro' ? 'Client' : 'Professional'} sign in.');
        }
        if (type != null) await _rememberMe();
        if (!mounted) return;
        if (type == null) {
          setState(() {
            _mode = 'onboard';
            _history = [_View.type];
          });
          return;
        }
        context.go(type.homePath);
      });

  Future<void> _finish() => _run(() async {
        if (_mode == 'reset') {
          await _auth.setPhonePassword(_pass.text);
          ref.invalidate(accountProfileProvider);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
          context.go(AppRoutes.home);
          return;
        }
        final profile = _auth.createRoleProfile(type: _role, name: _name.text.trim(), category: _cat, phone: _e164(ref.read(pendingPhoneProvider)));
        if (_mode == 'signup') {
          await Future.wait([_auth.setPhonePassword(_pass.text), profile]);
        } else {
          await profile;
        }
        ref.invalidate(accountProfileProvider);
        await ref.read(accountProfileProvider.future);
        await _rememberMe();
        if (mounted) context.go(_role.homePath);
      });

  static String _e164(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '';
    if (d.startsWith('233')) return '+$d';
    if (d.startsWith('0')) return '+233${d.substring(1)}';
    return '+233$d';
  }

  // ---------- layout ----------
  @override
  Widget build(BuildContext context) {
    final flow = _flows[_mode] ?? const <_View>[];
    final idx = flow.indexOf(_view);
    final first = _history.length <= 1;
    final showHead = !first || (_view != _View.type && _view != _View.choose && _view != _View.entry);
    final showBrand = _view == _View.entry || _view == _View.type || _view == _View.signin || _view == _View.choose;
    return PopScope(
      canPop: _history.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: AppBackdrop(
          art: true,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 60,
                        child: !showHead && first && _view == _View.type && _mode != 'onboard'
                            ? Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => context.go(AppRoutes.discover),
                                  child: Text('Browse professionals', style: AppTextStyles.caption.copyWith(fontSize: 13, color: const Color(0xFFE6E6E6), fontWeight: FontWeight.w500)),
                                ),
                              )
                            : showHead
                            ? Row(
                                children: [
                                  _RoundButton(icon: Icons.chevron_left_rounded, onTap: _back),
                                  if (idx >= 0) ...[
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 18),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(99),
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(end: (idx + 1) / flow.length),
                                            duration: const Duration(milliseconds: 350),
                                            builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: const Color(0x1FFFFFFF), color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 74, child: Text('Step ${idx + 1} of ${flow.length}', textAlign: TextAlign.right, style: AppTextStyles.caption.copyWith(fontSize: 12.5, color: AppColors.muted))),
                                  ] else
                                    const Spacer(),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (showBrand) const Padding(padding: EdgeInsets.only(top: 6), child: BrandFrame(size: 92)),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(position: Tween(begin: const Offset(.04, 0), end: Offset.zero).animate(a), child: child),
                          ),
                          child: KeyedSubtree(key: ValueKey(_view), child: _body()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_view) {
        _View.entry => _entryView(),
        _View.choose => _chooseView(),
        _View.type => _typeView(),
        _View.signin => _signinView(),
        _View.phone => _phoneView(),
        _View.code => _codeView(),
        _View.name => _nameView(),
        _View.cat => _catView(),
        _View.pass => _passView(),
      };

  Widget _page({required String title, String? sub, required List<Widget> children, required List<Widget> foot, bool small = false, bool scroll = true}) {
    final head = [
      SizedBox(height: small ? 2 : 20),
      Text(title, textAlign: TextAlign.center, style: AppTextStyles.headline.copyWith(fontSize: small ? 17 : 25, fontWeight: FontWeight.w700, shadows: const [Shadow(color: Color(0x80000000), blurRadius: 24)])),
      const SizedBox(height: 6),
      if (sub != null) ...[
        Text(sub, textAlign: TextAlign.center, style: AppTextStyles.body.copyWith(fontSize: 14, color: const Color(0xFFD0D0D0), fontWeight: FontWeight.w400, shadows: const [Shadow(color: Color(0xB3000000), blurRadius: 10)])),
        const SizedBox(height: 20),
      ],
    ];
    final footer = Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: foot),
    );
    if (!scroll) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...head, ...children, footer]);
    }
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...head, ...children, const Spacer(), footer],
            ),
          ),
        ),
      ),
    );
  }

  Widget _err() => AnimatedSize(
        duration: const Duration(milliseconds: 180),
        child: _error == null
            ? const SizedBox(height: 20)
            : Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 0), child: Text(_error!, style: AppTextStyles.caption.copyWith(fontSize: 12.5, color: const Color(0xFFFF9A8F)))),
      );

  // type
  Widget _typeView() {
    final onboard = _mode == 'onboard';
    final g = _groups[_group];
    return _page(
      title: onboard ? 'Finish setting up' : _intent ? (g?.$4 ?? 'Sign in') : (g?.$2 ?? 'Choose type'),
      sub: onboard ? 'Choose the account that fits how you use BAID X.' : _intent ? 'Choose your account type to continue.' : (g?.$3 ?? 'Pick the account that fits how you use BAID X.'),
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            // sized from the screen, not a LayoutBuilder: this sits inside IntrinsicHeight
            for (final t in _roles)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width.clamp(0, 440) - 36 - 10) / 2,
                child: _TypeTile(type: t, selected: _role == t, onTap: () => setState(() => _role = t)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(_role.summary, textAlign: TextAlign.center, style: AppTextStyles.caption.copyWith(fontSize: 13, color: const Color(0xFFD0D0D0))),
      ],
      foot: [
        if (onboard)
          PillButton(label: 'Continue', onPressed: () => _go(_View.name))
        else if (_gate != null)
          PillButton(label: 'Continue', onPressed: () => setState(() {
                _mode = 'signup';
                _go(_View.phone);
              }))
        else ...[
          PillButton(
            label: _intent ? 'Continue' : 'Sign in',
            onPressed: () => setState(() {
              _mode = 'signin';
              _go(_View.signin);
            }),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() {
              _intent = false;
              _mode = 'signup';
              _go(_View.phone);
            }),
            child: Text(_intent ? 'New here? Create an account' : 'Create an account', style: AppTextStyles.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  void _openGate(String group, {required bool signIn}) => setState(() {
        _gate = group;
        _group = group;
        _role = _roles.first;
        _intent = false;
        _welcome = null;
        _mode = signIn ? 'signin' : 'signup';
        _go(signIn ? _View.signin : _View.type);
      });

  // entry: professional or client, then sign in or create an account
  Widget _entryView() {
    return _page(
      title: 'Welcome to BAID X',
      sub: 'Ghana\'s work network. How will you use it?',
      children: [
        _Gate(
          icon: Icons.handyman_outlined,
          title: 'Professional',
          sub: 'Workers, project managers and suppliers',
          chips: const ['Get verified and found', 'Jobs, projects and payouts'],
          delay: 0,
          onSignIn: () => _openGate('pro', signIn: true),
          onCreate: () => _openGate('pro', signIn: false),
        ),
        const SizedBox(height: 14),
        _Gate(
          icon: Icons.home_outlined,
          title: 'Client',
          sub: 'Homeowners and companies hiring',
          chips: const ['Hire verified people', 'Pay through escrow'],
          delay: 90,
          onSignIn: () => _openGate('client', signIn: true),
          onCreate: () => _openGate('client', signIn: false),
        ),
      ],
      foot: [
        TextButton(
          onPressed: () => context.go(AppRoutes.discover),
          child: Text('Explore BAID X first', style: AppTextStyles.caption.copyWith(fontSize: 13.5, color: const Color(0xFFE6E6E6), decoration: TextDecoration.underline, decorationColor: const Color(0x99E6E6E6))),
        ),
      ],
    );
  }

  // continue with (accounts used on this device)
  Widget _chooseView() {
    return _page(
      title: 'Continue with',
      sub: 'Accounts used on this device.',
      children: [
        for (final a in _accs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Glass(
              radius: 18,
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              onTap: () => _pickAccount(a),
              child: Row(children: [
                InitialsAvatar(name: a.name, photoUrl: a.photo, size: 44, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${AccountType.fromDatabase(a.role)?.label ?? 'BAID X'} account',
                        if (a.phone.replaceAll(RegExp(r'\D'), '').length > 6) () {
                          final d = a.phone.replaceAll(RegExp(r'\D'), '');
                          return '+${d.substring(0, 3)} ••• ${d.substring(d.length - 3)}';
                        }(),
                      ].join(' · '),
                      style: AppTextStyles.caption.copyWith(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ]),
                ),
                Text('Password', style: AppTextStyles.caption.copyWith(fontSize: 12, color: const Color(0xFFD6D6D6), fontWeight: FontWeight.w600)),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ]),
            ),
          ),
      ],
      foot: [
        PillButton(
          label: 'Use another account',
          light: false,
          onPressed: () => setState(() {
            _intent = _group != null;
            _mode = 'signin';
            _go(_group == null ? _View.entry : _View.type);
          }),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => setState(() {
            _intent = false;
            _mode = 'signup';
            _go(_group == null ? _View.entry : _View.type);
          }),
          child: Text('Create a new account', style: AppTextStyles.label.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // sign in
  Widget _signinView() {
    return _page(
      title: 'Welcome back',
      sub: _welcome ?? (_intent ? 'Signing in as ${_role.label}.' : _gate != null ? '${_gate == 'pro' ? 'Professional' : 'Client'} sign-in. Use the phone or email on your account.' : 'Sign in to your BAID X account.'),
      children: [
        _Seg(phone: _usePhone, onChanged: (v) => setState(() {
              _usePhone = v;
              _error = null;
            })),
        const SizedBox(height: 16),
        if (_usePhone) _PhoneField(controller: _siPhone, key: const Key('siPhone')) else _GlassField(controller: _email, hint: 'Email address', keyboard: TextInputType.emailAddress, key: const Key('siEmail')),
        const SizedBox(height: 14),
        _GlassField(
          controller: _siPass,
          hint: 'Password',
          obscure: !_showPw,
          key: const Key('siPass'),
          suffix: IconButton(onPressed: () => setState(() => _showPw = !_showPw), icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF9A9A9A))),
          onSubmitted: (_) => _signIn(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4), foregroundColor: const Color(0xFFD6D6D6)),
            onPressed: () => setState(() {
              _mode = 'reset';
              _history = [_View.signin, _View.phone];
              _error = null;
            }),
            child: Text('Forgot password?', style: AppTextStyles.caption.copyWith(fontSize: 13, color: const Color(0xFFD6D6D6), fontWeight: FontWeight.w600)),
          ),
        ),
        _err(),
      ],
      foot: [PillButton(label: 'Sign in', loading: _busy, onPressed: _signIn)],
    );
  }

  // phone
  Widget _phoneView() {
    final valid = Validators.ghanaPhone(_phone.text) == null;
    return _page(
      title: 'Phone number',
      sub: _mode == 'reset' ? 'Enter the number on your account. We\'ll text you a code.' : 'A verification code will be sent to this number.',
      children: [_PhoneField(controller: _phone, autofocus: true, key: const Key('phone'), valid: valid), _err()],
      foot: [PillButton(label: 'Continue', loading: _busy, onPressed: valid ? _sendCode : null)],
    );
  }

  // code
  Widget _codeView() {
    return _page(
      title: 'Confirm phone number',
      sub: 'Enter the confirmation code sent to ${_e164(_phone.text).replaceFirstMapped(RegExp(r'^\+233(\d{2})(\d{3})(\d{4})$'), (m) => '+233 ${m[1]} ${m[2]} ${m[3]}')}.',
      children: [
        _Otp(controller: _code, focus: _codeFocus, state: _otpState, onComplete: _verify),
        const SizedBox(height: 6),
        if (_otpState == _OtpState.ok) const _Seal(),
        if (_otpState != _OtpState.ok) ...[
          _err(),
          Center(
            child: TextButton(
              onPressed: _resendLeft > 0 || _busy ? null : _sendCode,
              child: Text(_resendLeft > 0 ? 'Resend code in ${_resendLeft}s' : 'Resend code', style: AppTextStyles.label.copyWith(color: _resendLeft > 0 ? AppColors.muted : Colors.white)),
            ),
          ),
        ],
      ],
      foot: [PillButton(label: 'Continue', loading: _otpState == _OtpState.checking, onPressed: _code.text.length == 6 && _otpState == _OtpState.idle ? _verify : null)],
    );
  }

  (String, String, String) get _nameCopy => switch (_role) {
        AccountType.worker => ('Your name', 'Keep the account simple and identifiable. This is the name other people will see.', 'Enter your full name'),
        AccountType.company => ('Company name', 'Use your registered or trading name. Clients and professionals will see this.', 'Enter your company name'),
        AccountType.projectManager => ('Your name', 'Keep the account simple and identifiable. This is the name other people will see.', 'Enter your full name'),
        AccountType.business => ('Business name', 'Use the name your customers know you by.', 'Enter your business name'),
        AccountType.employer => ('Your name', 'Keep the account simple and identifiable. This is the name professionals will see.', 'Enter your full name'),
      };

  Widget _nameView() {
    final (title, help, ph) = _nameCopy;
    final ok = _name.text.trim().length >= 2;
    return _page(
      title: title,
      sub: help,
      children: [_GlassField(controller: _name, hint: ph, autofocus: true, caps: TextCapitalization.words, key: const Key('name'), onSubmitted: (_) => ok ? _go(_View.cat) : null)],
      foot: [PillButton(label: 'Continue', onPressed: ok ? () => _go(_View.cat) : null)],
    );
  }

  (String, String, List<RoleCategory>) get _catCopy => switch (_role) {
        AccountType.worker => ('Trade category', 'Choose the trade you work in.', jobCategories),
        AccountType.company => ('Industry', 'Choose the industry your company works in.', industries),
        AccountType.projectManager => ('Specialization', 'Choose the kind of projects you manage.', specializations),
        AccountType.business => ('Supply category', 'Choose the main thing you supply.', supplyCategories),
        AccountType.employer => ('What do you need done?', 'Choose the trade you hire for most.', clientNeeds),
      };

  Widget _catView() {
    final (title, help, all) = _catCopy;
    final q = _catQ.text.trim().toLowerCase();
    final list = q.isEmpty ? all : all.where((c) => c.name.toLowerCase().contains(q) || c.desc.toLowerCase().contains(q)).toList();
    final grouped = q.isEmpty && list.any((c) => c.group.isNotEmpty);
    final rows = <Widget>[];
    String? last;
    for (final c in list) {
      if (grouped && c.group != last) {
        last = c.group;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text(c.group.toUpperCase(), style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .9, color: const Color(0xFF9A9A9A))),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _CatRow(cat: c, selected: _cat?.id == c.id, showDesc: !grouped, onTap: () {
          setState(() => _cat = c);
          Future.delayed(const Duration(milliseconds: 180), () {
            if (mounted && _view == _View.cat) _mode == 'onboard' ? _finish() : _go(_View.pass);
          });
        }),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 2),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.headline.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(help, textAlign: TextAlign.center, style: AppTextStyles.body.copyWith(fontSize: 14, color: const Color(0xFFD0D0D0), fontWeight: FontWeight.w400)),
        const SizedBox(height: 14),
        if (all.length > 8) ...[
          _GlassField(controller: _catQ, hint: 'Search', prefix: const Icon(Icons.search, color: Color(0xFF9A9A9A), size: 20), height: 44, radius: 12),
          const SizedBox(height: 10),
        ],
        if (_busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
        _err(),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('No matches', style: AppTextStyles.bodyMuted.copyWith(color: AppColors.muted)))
              : ListView(padding: const EdgeInsets.only(bottom: 8), children: rows),
        ),
      ],
    );
  }

  Widget _passView() {
    final p = _pass.text;
    final rules = [
      ('At least 8 characters', p.length >= 8),
      ('A number', RegExp(r'\d').hasMatch(p)),
      ('A letter', RegExp(r'[A-Za-z]').hasMatch(p)),
      ('A capital letter or a symbol', RegExp(r'[A-Z]').hasMatch(p) || RegExp(r'[^A-Za-z0-9]').hasMatch(p)),
    ];
    final score = rules.where((r) => r.$2).length;
    final ok = Validators.strongPassword(p) == null;
    final label = p.isEmpty ? '' : ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'][score];
    return _page(
      title: _mode == 'reset' ? 'New password' : 'Create a password',
      sub: 'Use a secure password for sign-in. Your account will still be tied to mobile authentication.',
      children: [
        _GlassField(
          controller: _pass,
          hint: 'Create your password',
          obscure: !_showPw,
          autofocus: true,
          key: const Key('pass'),
          suffix: IconButton(onPressed: () => setState(() => _showPw = !_showPw), icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF9A9A9A))),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 4,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), color: i < score ? const Color(0xFF7DD3FC) : const Color(0x1FFFFFFF)),
                ),
              ),
              if (i < 3) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF7DD3FC))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (final r in rules)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(r.$2 ? Icons.check_circle : Icons.radio_button_unchecked, size: 15, color: r.$2 ? AppColors.green : AppColors.muted),
                const SizedBox(width: 5),
                Text(r.$1, style: AppTextStyles.caption.copyWith(fontSize: 12, color: r.$2 ? AppColors.green : AppColors.muted)),
              ]),
          ],
        ),
        _err(),
      ],
      foot: [
        PillButton(label: _mode == 'reset' ? 'Save password' : 'Create account', loading: _busy, onPressed: ok ? _finish : null),
        if (_mode != 'reset')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'BAID X has no tolerance for objectionable content or abusive users. By continuing, you agree to the Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.muted, height: 1.5),
            ),
          ),
      ],
    );
  }
}

// ---------- pieces ----------

/// One side of the entry screen: a liquid-glass panel with its own sign-in and create buttons.
class _Gate extends StatelessWidget {
  const _Gate({required this.icon, required this.title, required this.sub, required this.chips, required this.delay, required this.onSignIn, required this.onCreate});
  final IconData icon;
  final String title;
  final String sub;
  final List<String> chips;
  final int delay;
  final VoidCallback onSignIn;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + delay),
      curve: Interval(delay / (700 + delay), 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child)),
      child: Glass(
        radius: 26,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x55FFFFFF), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -8)]),
                child: Icon(icon, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: AppTextStyles.headline.copyWith(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.3)),
                  const SizedBox(height: 2),
                  Text(sub, style: AppTextStyles.caption.copyWith(fontSize: 13, color: const Color(0xFFCFCFCF))),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in chips)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x29FFFFFF))),
                  child: Text(c, style: AppTextStyles.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFE6E6E6))),
                ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: PillButton(label: 'Sign in', height: 48, onPressed: onSignIn)),
              const SizedBox(width: 10),
              Expanded(child: PillButton(label: 'Create account', light: false, height: 48, onPressed: onCreate)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x1AFFFFFF), border: Border.all(color: const Color(0x38FFFFFF))),
          child: Icon(icon, size: 24, color: Colors.white),
        ),
      ),
    );
  }
}

IconData _roleIcon(AccountType t) => switch (t) {
      AccountType.worker => Icons.engineering_outlined,
      AccountType.company => Icons.apartment_outlined,
      AccountType.projectManager => Icons.assignment_outlined,
      AccountType.business => Icons.local_shipping_outlined,
      AccountType.employer => Icons.home_outlined,
    };

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.type, required this.selected, required this.onTap});
  final AccountType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Glass(
          selected: selected,
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Icon(_roleIcon(type), size: 32, color: Colors.white)),
              const SizedBox(height: 8),
              Text(type.label, textAlign: TextAlign.center, style: AppTextStyles.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFE8E8E8))),
            ],
          ),
        ),
        if (selected)
          Positioned(
            top: 8,
            right: 8,
            child: Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: const Icon(Icons.check, size: 11, color: Colors.black)),
          ),
      ],
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.phone, required this.onChanged});
  final bool phone;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String t, bool on, bool v) => Expanded(
          child: GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                boxShadow: on ? const [BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 6))] : null,
              ),
              child: Text(t, style: AppTextStyles.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? Colors.black : AppColors.muted)),
            ),
          ),
        );
    return Glass(
      radius: 18,
      padding: const EdgeInsets.all(4),
      child: Row(children: [tab('Phone', phone, true), tab('Email', !phone, false)]),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboard,
    this.suffix,
    this.prefix,
    this.autofocus = false,
    this.caps = TextCapitalization.none,
    this.onSubmitted,
    this.height = 52,
    this.radius = 16,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? suffix;
  final Widget? prefix;
  final bool autofocus;
  final TextCapitalization caps;
  final ValueChanged<String>? onSubmitted;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: radius,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (prefix != null) Padding(padding: const EdgeInsets.only(left: 14), child: prefix),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboard,
                autofocus: autofocus,
                textCapitalization: caps,
                onSubmitted: onSubmitted,
                style: AppTextStyles.body.copyWith(fontSize: 15.5, fontWeight: FontWeight.w400),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: false,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            ?suffix,
          ],
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, this.autofocus = false, this.valid = false, super.key});
  final TextEditingController controller;
  final bool autofocus;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 16,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 14),
            const _GhanaFlag(),
            const SizedBox(width: 8),
            Text('+233', style: AppTextStyles.body.copyWith(fontSize: 14, color: const Color(0xFFDDDDDD), fontWeight: FontWeight.w500)),
            const Icon(Icons.expand_more, size: 18, color: Color(0xFFDDDDDD)),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: autofocus,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(16)],
                style: AppTextStyles.body.copyWith(fontSize: 15.5, fontWeight: FontWeight.w400),
                decoration: const InputDecoration(hintText: '0201234567', filled: false, isCollapsed: true, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: valid ? 1 : 0,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 22,
                height: 22,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7DD3FC)),
                child: const Icon(Icons.check, size: 15, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhanaFlag extends StatelessWidget {
  const _GhanaFlag();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: 22,
        height: 15,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(children: [
              Expanded(child: Container(color: const Color(0xFFCE1126))),
              Expanded(child: Container(color: const Color(0xFFFCD116))),
              Expanded(child: Container(color: const Color(0xFF006B3F))),
            ]),
            const Icon(Icons.star, size: 6, color: Colors.black),
          ],
        ),
      ),
    );
  }
}

enum _OtpState { idle, checking, ok, bad }

/// Six glass boxes over one hidden field, with the website's motion: the active
/// box lifts, a filled box pops, checking ripples, a right code glows green and a
/// wrong one shakes red.
class _Otp extends StatefulWidget {
  const _Otp({required this.controller, required this.focus, required this.state, required this.onComplete});
  final TextEditingController controller;
  final FocusNode focus;
  final _OtpState state;
  final VoidCallback onComplete;

  @override
  State<_Otp> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_Otp> with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(covariant _Otp old) {
    super.didUpdateWidget(old);
    if (widget.state == _OtpState.checking && old.state != _OtpState.checking) _wave.repeat();
    if (widget.state != _OtpState.checking) _wave.stop();
    if (widget.state == _OtpState.bad && old.state != _OtpState.bad) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _wave.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: () => widget.focus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 52,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                onChanged: (v) {
                  if (v.length == 6) widget.onComplete();
                },
              ),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_wave, _shake, widget.focus]),
            builder: (context, _) {
              final shakeX = _shake.isAnimating ? 9 * (1 - _shake.value) * (((_shake.value * 10).floor().isEven) ? 1 : -1) : 0.0;
              return Transform.translate(
                offset: Offset(shakeX, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      _box(i, text, widget.focus.hasFocus && (text.length == i || (i == 5 && text.length == 6))),
                      if (i < 5) const SizedBox(width: 10),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _box(int i, String text, bool active) {
    final filled = i < text.length;
    final s = widget.state;
    double lift = active ? -3 : 0;
    if (s == _OtpState.checking) {
      final t = (_wave.value - i * .09) % 1;
      lift = -7 * (t < .4 ? t / .4 : (t < .8 ? (.8 - t) / .4 : 0));
    }
    final (border, bg, glow) = switch (s) {
      _OtpState.ok => (const Color(0xFFBFF3D9), const [Color(0x6634D399), Color(0x1434D399)], const Color(0x8C34D399)),
      _OtpState.bad => (const Color(0xFFFF8A8A), const [Color(0x61F87171), Color(0x14F87171)], const Color(0xA6F87171)),
      _OtpState.checking => (const Color(0xBF7DD3FC), const [Color(0x2EFFFFFF), Color(0x0FFFFFFF)], const Color(0x667DD3FC)),
      _OtpState.idle => (
          active ? Colors.white : (filled ? const Color(0xB3FFFFFF) : const Color(0x4DFFFFFF)),
          filled ? const [Color(0x42FFFFFF), Color(0x12FFFFFF)] : const [Color(0x9E0E0E0E), Color(0x570E0E0E), Color(0x24FFFFFF)],
          active ? const Color(0x737DD3FC) : Colors.transparent,
        ),
    };
    return TweenAnimationBuilder<double>(
      key: ValueKey('$i-$filled'),
      tween: Tween(begin: filled ? .82 : 1, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: const Cubic(.2, 1.2, .3, 1),
      builder: (context, scale, child) => Transform.translate(
        offset: Offset(0, lift),
        child: Transform.scale(scale: active && s == _OtpState.idle ? 1.06 : scale, child: child),
      ),
      child: Container(
        width: 44,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bg),
          border: Border.all(color: border, width: 1.5),
          boxShadow: [BoxShadow(color: glow, blurRadius: 24, spreadRadius: -2), const BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 14))],
        ),
        child: Text(
          filled ? text[i] : '',
          style: TextStyle(
            fontFamily: AppTextStyles.family,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: s == _OtpState.ok ? const Color(0xFFEAFFF4) : s == _OtpState.bad ? const Color(0xFFFFE3E3) : Colors.white,
            shadows: filled ? const [Shadow(color: Color(0xB3FFFFFF), blurRadius: 14)] : null,
          ),
        ),
      ),
    );
  }
}

/// "Verified" seal after a right code: a green ring draws itself and a check appears.
class _Seal extends StatelessWidget {
  const _Seal();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: (1 - v).clamp(0, 1) * .9,
                    child: Transform.scale(scale: .45 + 1.2 * v, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xCCBEF3D9), width: 1.5)))),
                  ),
                  Container(
                    width: 96 * (.6 + .4 * v),
                    height: 96 * (.6 + .4 * v),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x8C10201A),
                      border: Border.all(color: Color.lerp(const Color(0xFFBFF3D9), const Color(0xFF7DD3FC), v)!, width: 3),
                      boxShadow: [BoxShadow(color: const Color(0xB334D399).withValues(alpha: .7 * v), blurRadius: 18)],
                    ),
                    child: Opacity(opacity: v, child: const Icon(Icons.check_rounded, size: 52, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: v,
              child: const Text('VERIFIED', style: TextStyle(fontFamily: AppTextStyles.family, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 3.8, color: Color(0xFFD9FBE9), shadows: [Shadow(color: Color(0xCC34D399), blurRadius: 16)])),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatRow extends StatelessWidget {
  const _CatRow({required this.cat, required this.selected, required this.onTap, this.showDesc = true});
  final RoleCategory cat;
  final bool selected;
  final bool showDesc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 14,
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? Colors.white : const Color(0xFF2A2A2A)),
            child: Icon(Icons.work_outline, size: 18, color: selected ? Colors.black : const Color(0xFFCFCFCF)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.name, style: AppTextStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                if (showDesc && cat.desc.isNotEmpty) Text(cat.desc, style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
