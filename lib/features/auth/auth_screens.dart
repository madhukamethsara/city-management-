import 'package:flutter/material.dart';

import '../../core/constants/app_copy.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 760;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: wide
                      ? Row(
                          children: <Widget>[
                            const Expanded(flex: 6, child: _WelcomeHero()),
                            const SizedBox(width: 38),
                            Expanded(flex: 4, child: _WelcomeActions()),
                          ],
                        )
                      : const Column(
                          children: <Widget>[
                            _WelcomeHero(),
                            SizedBox(height: 24),
                            _WelcomeActions(),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.deepGreen, AppColors.green],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -46,
            bottom: -52,
            child: Icon(
              Icons.account_balance_outlined,
              size: 230,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppLogo(inverse: true),
              const SizedBox(height: 48),
              Text(
                'Your local authority,\ncloser to your community.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Discover public projects, report local problems, follow progress and take part in better local government.',
                style: TextStyle(
                  color: Color(0xFFE1F8F2),
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _HeroChip(icon: Icons.map_outlined, label: 'Local projects'),
                  _HeroChip(
                    icon: Icons.report_problem_outlined,
                    label: 'Issue tracking',
                  ),
                  _HeroChip(
                    icon: Icons.forum_outlined,
                    label: 'Community voice',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AppLogo(),
        const SizedBox(height: 30),
        Text(
          'Welcome to Smart Sabha',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          AppCopy.text('tagline'),
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          icon: const Icon(Icons.login),
          label: const Text('Sign in'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Create an account'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            AppScope.of(context).continueAsGuest();
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          },
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Explore public information as a guest'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Your exact residential location is never shown publicly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(
    text: 'citizen@smart-sabha.lk',
  );
  final _passwordController = TextEditingController(text: 'demo12345');
  bool _hidePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await AppScope.of(
      context,
    ).signIn(email: _emailController.text, password: _passwordController.text);
    if (!mounted) return;
    final controller = AppScope.of(context);
    Navigator.pushNamedAndRemoveUntil(
      context,
      controller.isOfficer ? '/admin' : '/',
      (route) => false,
    );
  }

  void _setDemo(String email) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = 'demo12345';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign in to your community',
      subtitle: 'Access your local projects, reports and community updates.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.length < 6
                  ? 'Use at least 6 characters.'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Demo accounts',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: <Widget>[
                ActionChip(
                  label: const Text('Citizen demo'),
                  onPressed: () => _setDemo('citizen@smart-sabha.lk'),
                ),
                ActionChip(
                  label: const Text('Officer demo'),
                  onPressed: () => _setDemo('officer@smart-sabha.lk'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text('New to Smart Sabha?'),
                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/register'),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _accepted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || !_accepted) {
      if (!_accepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the privacy notice to continue.'),
          ),
        );
      }
      return;
    }
    setState(() => _submitting = true);
    await AppScope.of(
      context,
    ).register(fullName: _nameController.text, email: _emailController.text);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your citizen account',
      subtitle:
          'We will ask for your local authority and ward in the next step.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => value == null || value.trim().length < 3
                  ? 'Enter your full name.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match.'
                  : null,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I understand that my contact and exact location remain private.',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitting ? null : _register,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Already have an account?'),
                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _sent ? 'Check your inbox' : 'Reset your password',
      subtitle: _sent
          ? 'If an account exists for this email, a password-reset link has been sent.'
          : 'Enter the email linked to your Smart Sabha account.',
      child: _sent
          ? FilledButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              ),
              child: const Text('Back to sign in'),
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter a valid email address.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _sent = true);
                      }
                    },
                    child: const Text('Send reset link'),
                  ),
                ],
              ),
            ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'Use a strong password you do not reuse elsewhere.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
              validator: (value) =>
                  value != _password.text ? 'Passwords do not match.' : null,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password updated. You can now sign in.'),
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                }
              },
              child: const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppLogo(),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 26),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
