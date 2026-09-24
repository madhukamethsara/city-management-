import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/domain_models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/civic_map.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _personalFormKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  int _step = 0;
  bool _hydrated = false;
  String _language = 'en';
  String? _authorityId;
  String _ward = 'Ward 04';
  String _gnDivision = 'Kumbukgate South';
  GeoPoint? _residentialArea;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    final controller = AppScope.of(context);
    final user = controller.currentUser;
    _nameController.text = user?.fullName ?? '';
    _phoneController.text = user?.phone ?? '';
    _language = user?.preferredLanguage ?? 'en';
    _authorityId = user?.localAuthorityId.isNotEmpty == true
        ? user!.localAuthorityId
        : controller.authorities.first.id;
    _ward = user?.ward.isNotEmpty == true ? user!.ward : _ward;
    _gnDivision = user?.gnDivision.isNotEmpty == true
        ? user!.gnDivision
        : _gnDivision;
    _residentialArea = user?.residentialArea;
    _hydrated = true;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  LocalAuthority get _authority => AppScope.of(
    context,
  ).authorities.firstWhere((authority) => authority.id == _authorityId);

  Future<void> _next() async {
    if (_step == 0 && !_personalFormKey.currentState!.validate()) return;
    if (_step == 1 && !_locationFormKey.currentState!.validate()) return;
    if (_step == 4) {
      _complete();
      return;
    }
    setState(() => _step += 1);
    await _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    if (_step == 0) return;
    setState(() => _step -= 1);
    await _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _complete() {
    AppScope.of(context).completeOnboarding(
      OnboardingDraft(
        fullName: _nameController.text.trim(),
        language: _language,
        phone: _phoneController.text.trim(),
        localAuthorityId: _authorityId!,
        ward: _ward,
        gnDivision: _gnDivision,
        residentialArea: _residentialArea,
      ),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_step) {
      0 => 'Continue to location',
      1 => 'Continue to map',
      2 => 'Review details',
      3 => 'Complete account',
      _ => 'Enter Smart Sabha',
    };
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? null
            : IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back)),
        title: const Text('Set up your local profile'),
      ),
      body: ResponsivePage(
        child: Column(
          children: <Widget>[
            _OnboardingProgress(step: _step),
            const SizedBox(height: 22),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  _personalStep(),
                  _locationStep(),
                  _mapStep(),
                  _reviewStep(),
                  _completeStep(),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Row(
                children: <Widget>[
                  if (_step > 0) ...<Widget>[
                    OutlinedButton(onPressed: _back, child: const Text('Back')),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(onPressed: _next, child: Text(label)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalStep() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _personalFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const PageHeader(
                icon: Icons.person_outline,
                title: 'Tell us about yourself',
                subtitle:
                    'This information is private and helps us personalise local services.',
              ),
              const SizedBox(height: 26),
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
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _language,
                decoration: const InputDecoration(
                  labelText: 'Preferred language',
                  prefixIcon: Icon(Icons.language_outlined),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'si', child: Text('සිංහල')),
                  DropdownMenuItem(value: 'ta', child: Text('தமிழ்')),
                ],
                onChanged: (value) => setState(() => _language = value ?? 'en'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) => value == null || value.trim().length < 8
                    ? 'Enter a valid phone number.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationStep() {
    final authorities = AppScope.of(context).authorities;
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _locationFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const PageHeader(
                icon: Icons.location_city_outlined,
                title: 'Choose your service area',
                subtitle:
                    'This controls which local notices, projects and services you see.',
              ),
              const SizedBox(height: 26),
              DropdownButtonFormField<String>(
                value: _authorityId,
                decoration: const InputDecoration(
                  labelText: 'Local authority',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                items: authorities
                    .map(
                      (authority) => DropdownMenuItem(
                        value: authority.id,
                        child: Text(authority.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _authorityId = value),
                validator: (value) =>
                    value == null ? 'Select your local authority.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _ward,
                decoration: const InputDecoration(
                  labelText: 'Ward',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'Ward 01', child: Text('Ward 01')),
                  DropdownMenuItem(value: 'Ward 02', child: Text('Ward 02')),
                  DropdownMenuItem(value: 'Ward 03', child: Text('Ward 03')),
                  DropdownMenuItem(value: 'Ward 04', child: Text('Ward 04')),
                ],
                onChanged: (value) => setState(() => _ward = value ?? _ward),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _gnDivision,
                decoration: const InputDecoration(
                  labelText: 'GN division',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                onChanged: (value) => _gnDivision = value,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your GN division.'
                    : null,
              ),
              const SizedBox(height: 20),
              CivicCard(
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.deepGreen,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your selected service area is used to provide relevant information. It does not publish your address or precise home location.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PageHeader(
            icon: Icons.pin_drop_outlined,
            title: 'Set an approximate location',
            subtitle:
                'Tap the map near your residence. This is optional and never displayed publicly.',
          ),
          const SizedBox(height: 20),
          CivicMap(
            center: _authority.center,
            height: 385,
            selectedPoint: _residentialArea,
            onTap: (point) => setState(() => _residentialArea = point),
          ),
          const SizedBox(height: 12),
          CivicCard(
            child: Row(
              children: <Widget>[
                const Icon(Icons.shield_outlined, color: AppColors.deepGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _residentialArea == null
                        ? 'No approximate location selected yet.'
                        : 'Approximate location selected: ${_residentialArea!.shortLabel}',
                  ),
                ),
                if (_residentialArea != null)
                  TextButton(
                    onPressed: () => setState(() => _residentialArea = null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PageHeader(
              icon: Icons.fact_check_outlined,
              title: 'Review your profile',
              subtitle:
                  'You can edit these account details later in Profile settings.',
            ),
            const SizedBox(height: 22),
            CivicCard(
              child: Column(
                children: <Widget>[
                  _ReviewRow(label: 'Name', value: _nameController.text),
                  _ReviewRow(
                    label: 'Language',
                    value: _language == 'si'
                        ? 'සිංහල'
                        : _language == 'ta'
                        ? 'தமிழ்'
                        : 'English',
                  ),
                  _ReviewRow(label: 'Phone', value: _phoneController.text),
                  _ReviewRow(label: 'Local authority', value: _authority.name),
                  _ReviewRow(label: 'Ward', value: _ward),
                  _ReviewRow(label: 'GN division', value: _gnDivision),
                  _ReviewRow(
                    label: 'Approximate map location',
                    value: _residentialArea == null
                        ? 'Not selected'
                        : 'Selected privately',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completeStep() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.deepGreen,
                size: 62,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Your local profile is ready',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'You will now receive services and public information for ${_authority.name}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['You', 'Area', 'Map', 'Review', 'Done'];
    return Column(
      children: <Widget>[
        LinearProgressIndicator(
          value: (step + 1) / labels.length,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(
            labels.length,
            (index) => Text(
              labels[index],
              style: TextStyle(
                color: index <= step ? AppColors.deepGreen : AppColors.muted,
                fontSize: 12,
                fontWeight: index == step ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 154,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
