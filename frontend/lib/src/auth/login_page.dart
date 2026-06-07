import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../features/dashboard/signed_in_page.dart';
import 'auth_service.dart';

enum _AuthMode { signIn, signUp }

class LoginPage extends StatefulWidget {
  const LoginPage({required this.authService, super.key});

  final AuthService authService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _rememberMe = true;
  bool _termsAccepted = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _emailBusy = false;
  bool _googleBusy = false;

  bool get _busy => _emailBusy || _googleBusy;
  bool get _isSignUp => _mode == _AuthMode.signUp;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    if (_mode == mode || _busy) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _mode = mode;
      _termsAccepted = false;
      _passwordVisible = false;
      _confirmPasswordVisible = false;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submitEmailPassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isSignUp && !_termsAccepted) {
      _showResult(
        AuthActionResult.failed('Accept the account terms to continue.'),
      );
      return;
    }

    setState(() => _emailBusy = true);
    final result = _isSignUp
        ? await widget.authService.createAccountWithEmailAndPassword(
            displayName: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          )
        : await widget.authService.signInWithEmailAndPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );

    if (!mounted) {
      return;
    }

    setState(() => _emailBusy = false);
    _showResult(result);
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();

    setState(() => _googleBusy = true);
    final result = await widget.authService.signInWithGoogle();

    if (!mounted) {
      return;
    }

    setState(() => _googleBusy = false);
    _showResult(result);
  }

  Future<void> _sendPasswordReset() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    if (email.isEmpty || _emailValidator(email) != null) {
      _showResult(AuthActionResult.failed('Enter your email address first.'));
      return;
    }

    final result = await widget.authService.sendPasswordResetEmail(email);

    if (!mounted) {
      return;
    }

    _showResult(result);
  }

  void _showResult(AuthActionResult result) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: result.success ? AppTheme.graphite : scheme.error,
          content: Text(result.message),
        ),
      );
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required.';
    }

    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  String? _nameValidator(String? value) {
    if (!_isSignUp) {
      return null;
    }

    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Name is required.';
    }
    if (name.length < 2) {
      return 'Enter at least 2 characters.';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (!_isSignUp) {
      return null;
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.authService.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return SignedInPage(user: user, authService: widget.authService);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1060) {
              return _DesktopLoginLayout(form: _buildForm(context));
            }
            return _CompactLoginLayout(form: _buildForm(context));
          },
        );
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AutofillGroup(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 34,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _KtmsMark(size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KTMS',
                            style: textTheme.titleLarge?.copyWith(
                              color: AppTheme.graphite,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Transportation Management',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.slate,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_AuthMode>(
                    showSelectedIcon: false,
                    selected: <_AuthMode>{_mode},
                    onSelectionChanged: _busy
                        ? null
                        : (selection) => _setMode(selection.single),
                    segments: const [
                      ButtonSegment<_AuthMode>(
                        value: _AuthMode.signIn,
                        icon: Icon(Icons.login_rounded),
                        label: Text('Sign in'),
                      ),
                      ButtonSegment<_AuthMode>(
                        value: _AuthMode.signUp,
                        icon: Icon(Icons.person_add_alt_1_rounded),
                        label: Text('Create account'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _isSignUp ? 'Create account' : 'Sign in',
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp
                      ? 'Request secure access for your transport workspace.'
                      : 'Secure access for enterprise transport operations.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppTheme.slate,
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 26),
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _nameController,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: _nameValidator,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: _emailValidator,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_busy,
                  obscureText: !_passwordVisible,
                  textInputAction: _isSignUp
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: _passwordValidator,
                  onFieldSubmitted: (_) {
                    if (!_isSignUp) {
                      _submitEmailPassword();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _passwordVisible
                          ? 'Hide password'
                          : 'Show password',
                      onPressed: _busy
                          ? null
                          : () {
                              setState(
                                () => _passwordVisible = !_passwordVisible,
                              );
                            },
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    enabled: !_busy,
                    obscureText: !_confirmPasswordVisible,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: _confirmPasswordValidator,
                    onFieldSubmitted: (_) => _submitEmailPassword(),
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        tooltip: _confirmPasswordVisible
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: _busy
                            ? null
                            : () {
                                setState(
                                  () => _confirmPasswordVisible =
                                      !_confirmPasswordVisible,
                                );
                              },
                        icon: Icon(
                          _confirmPasswordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (_isSignUp)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _termsAccepted,
                          onChanged: _busy
                              ? null
                              : (value) {
                                  setState(
                                    () => _termsAccepted = value ?? false,
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'I agree to the KTMS account terms.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: _busy
                              ? null
                              : (value) {
                                  setState(() => _rememberMe = value ?? true);
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Remember me',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _sendPasswordReset,
                        child: const Text('Forgot password'),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _submitEmailPassword,
                    icon: _emailBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isSignUp
                                ? Icons.person_add_alt_1_rounded
                                : Icons.login_rounded,
                          ),
                    label: Text(
                      _emailBusy
                          ? (_isSignUp ? 'Creating account' : 'Signing in')
                          : (_isSignUp ? 'Create account' : 'Sign in'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _DividerLabel(label: 'or'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _submitGoogle,
                    icon: _googleBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata_rounded, size: 30),
                    label: Text(
                      _googleBusy
                          ? 'Opening Google'
                          : (_isSignUp
                                ? 'Sign up with Google'
                                : 'Continue with Google'),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _setMode(
                            _isSignUp ? _AuthMode.signIn : _AuthMode.signUp,
                          ),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : 'Need an account? Create one',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopLoginLayout extends StatelessWidget {
  const _DesktopLoginLayout({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 11, child: _VisualPanel(compact: false)),
          Expanded(
            flex: 7,
            child: ColoredBox(
              color: AppTheme.panel,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 54,
                      vertical: 38,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: form,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactLoginLayout extends StatelessWidget {
  const _CompactLoginLayout({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _VisualPanel(compact: true)),
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 136),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: form,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualPanel extends StatelessWidget {
  const _VisualPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/ktms-login-hero.png',
          fit: BoxFit.cover,
          alignment: compact ? Alignment.topCenter : Alignment.center,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: compact
                  ? const [
                      Color(0xF0111827),
                      Color(0xB8111827),
                      Color(0x55111827),
                    ]
                  : const [
                      Color(0xF8111827),
                      Color(0xB0111827),
                      Color(0x33111827),
                    ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(compact ? 22 : 44),
            child: Align(
              alignment: compact ? Alignment.topLeft : Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 330 : 610),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _KtmsMark(size: 48, inverse: true),
                        const SizedBox(width: 14),
                        Text(
                          'KTMS',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                        ),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Transportation Control Tower',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.04,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Plan, dispatch, track, and settle freight operations from one secure workspace.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 28),
                      const _SignalRow(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: const [
        _SignalPill(icon: Icons.route_rounded, label: 'Live routes'),
        _SignalPill(icon: Icons.warehouse_rounded, label: 'Yard visibility'),
        _SignalPill(icon: Icons.verified_rounded, label: 'Controlled access'),
      ],
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF67E8F9), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppTheme.line)),
      ],
    );
  }
}

class _KtmsMark extends StatelessWidget {
  const _KtmsMark({required this.size, this.inverse = false});

  final double size;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: inverse
            ? Colors.white.withValues(alpha: 0.12)
            : AppTheme.graphite,
        borderRadius: BorderRadius.circular(8),
        border: inverse
            ? Border.all(color: Colors.white.withValues(alpha: 0.22))
            : Border.all(color: AppTheme.graphite),
      ),
      child: CustomPaint(painter: _RouteMarkPainter(inverse: inverse)),
    );
  }
}

class _RouteMarkPainter extends CustomPainter {
  const _RouteMarkPainter({required this.inverse});

  final bool inverse;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = inverse ? Colors.white : AppTheme.cyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = AppTheme.amber
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.23, size.height * 0.68)
      ..lineTo(size.width * 0.42, size.height * 0.43)
      ..lineTo(size.width * 0.62, size.height * 0.58)
      ..lineTo(size.width * 0.78, size.height * 0.31);

    canvas.drawPath(path, linePaint);

    for (final offset in <Offset>[
      Offset(size.width * 0.23, size.height * 0.68),
      Offset(size.width * 0.42, size.height * 0.43),
      Offset(size.width * 0.62, size.height * 0.58),
      Offset(size.width * 0.78, size.height * 0.31),
    ]) {
      canvas.drawCircle(offset, size.width * 0.055, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteMarkPainter oldDelegate) {
    return oldDelegate.inverse != inverse;
  }
}
