import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/tokens.dart';
import '../../../core/location/geo_repository.dart';
import '../../../core/location/location_service.dart';
import '../../../shared/widgets/gym_card.dart';
import '../../../shared/widgets/session_row.dart';
import '../../open_mats/models/open_mat.dart';
import '../data/search_query.dart';
import '../data/search_repository.dart';
import '../data/when_range.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // Active filter chips. Gi-type filters ('gi'/'nogi'/'both') OR among
  // themselves; 'free' is an independent toggle that ANDs with them. Empty =
  // no gi-type filtering. Only the LAST selected gi-type is sent to the API
  // (the backend takes a single giType), so gi-type behaves single-select.
  final Set<String> _filters = <String>{};
  double _distanceMi = 10.0;
  WhenRange? _when;
  String _whenLabel = 'Any time';
  final _searchCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  Timer? _debounce;

  // Captured GPS coordinates. These are the ONLY source of lat/lng; they are
  // suppressed whenever a zip is present (see _rebuildQuery).
  double? _gpsLat;
  double? _gpsLng;
  String? _locationLabel;

  SearchQuery _query = const SearchQuery(radiusKm: 16);

  @override
  void initState() {
    super.initState();
    _seedFromPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) => _useGps());
  }

  /// Seed the initial "When", "Within", and gi-type from the user's saved
  /// default search preferences, when present. Falls back to current defaults.
  void _seedFromPreferences() {
    final prefs = ref.read(authStateProvider).user?.preferences;
    if (prefs == null) return;

    final within = prefs.defaultWithinMi;
    if (within != null) _distanceMi = within.clamp(1.0, 100.0);

    final gi = prefs.defaultGiType;
    if (gi != null && ['gi', 'nogi', 'both'].contains(gi)) {
      _filters
        ..removeWhere((f) => f != 'free')
        ..add(gi);
    }

    final when = prefs.defaultWhen;
    if (when != null) {
      final now = DateTime.now();
      switch (when) {
        case 'this_week':
          _when = WhenRange.thisWeek(now);
          _whenLabel = 'This week';
        case 'this_weekend':
          _when = WhenRange.thisWeekend(now);
          _whenLabel = 'This weekend';
        case 'this_month':
          _when = WhenRange.thisMonth(now);
          _whenLabel = 'This month';
      }
    }
  }

  /// The token persisted for the current "When" selection, mirroring the
  /// labels used by [_whenOptions]. Null when no range is active.
  String? get _whenToken {
    switch (_whenLabel) {
      case 'This week':
        return 'this_week';
      case 'This weekend':
        return 'this_weekend';
      case 'This month':
        return 'this_month';
      default:
        return null;
    }
  }

  /// Persist the current When/Within/gi-type as the user's default search
  /// preferences and confirm with a SnackBar.
  Future<void> _saveAsDefault() async {
    final giType = _selectedGiType;
    final whenToken = _whenToken;
    await ref.read(authStateProvider.notifier).updateProfile({
      'preferences': {
        if (whenToken != null) 'defaultWhen': whenToken,
        'defaultWithinMi': _distanceMi,
        if (giType != null) 'defaultGiType': giType,
      },
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved as your default')),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  /// The gi-type sent to the API: the single selected gi-type chip, if any.
  String? get _selectedGiType {
    for (final id in ['gi', 'nogi', 'both']) {
      if (_filters.contains(id)) return id;
    }
    return null;
  }

  void _rebuildQuery() {
    // Enforce a single geo source: ZIP takes precedence when present, and
    // lat/lng derive ONLY from the captured GPS coords (suppressed when a zip
    // is set) — so we never send both zip and lat/lng.
    final zipText = _zipCtrl.text.trim();
    final useZip = zipText.isNotEmpty;
    setState(() {
      _query = SearchQuery(
        text: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        giType: _selectedGiType,
        free: _filters.contains('free'),
        when: _when,
        lat: useZip ? null : _gpsLat,
        lng: useZip ? null : _gpsLng,
        radiusKm: _distanceMi * 1.60934,
        zip: useZip ? zipText : null,
      );
    });
    // Cosmetic: warm the future so results paint without a loading flash;
    // family caching dedupes with the ref.watch in build (no double fetch).
    final query = _query;
    ref.read(searchResultsProvider(query).future).whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _rebuildQuery);
  }

  /// Rebuild the query on the next microtask/short delay so the new
  /// [searchResultsProvider] future has resolved before the next frame paints
  /// (avoids a lingering loading frame after immediate control changes).
  void _rebuildSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 50), _rebuildQuery);
  }

  void _toggleFilter(String id) {
    setState(() {
      if (_filters.contains(id)) {
        _filters.remove(id);
      } else {
        if (id != 'free') _filters.removeWhere((f) => f != 'free');
        _filters.add(id);
      }
    });
    _rebuildSoon();
  }

  void _setWhen(WhenRange range, String label) {
    setState(() {
      _when = range;
      _whenLabel = label;
    });
    _rebuildSoon();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    final label =
        '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
    _setWhen(WhenRange.singleDay(picked), label);
  }

  Future<void> _useGps() async {
    _debounce?.cancel();
    final loc = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    if (loc == null) {
      // Never fail silently — tell the user why and offer the ZIP fallback.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location unavailable. Turn on location and allow the permission, or search by ZIP.')),
      );
      return;
    }
    _gpsLat = loc.latitude;
    _gpsLng = loc.longitude;
    _zipCtrl.clear();
    _rebuildQuery();
    final rg = await ref.read(geoRepositoryProvider).reverse(loc.latitude, loc.longitude);
    if (mounted && rg != null) setState(() => _locationLabel = rg.label);
  }

  /// ZIP field changes: debounce, refresh results, and resolve the ZIP to a
  /// "City, ST" label shown in the location field.
  void _onZipChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _rebuildQuery();
      _resolveZipLabel();
    });
  }

  Future<void> _resolveZipLabel() async {
    final zip = _zipCtrl.text.trim();
    if (zip.isEmpty) {
      if (mounted) setState(() => _locationLabel = null);
      return;
    }
    if (zip.length != 5) return; // wait for a full 5-digit ZIP
    final rg = await ref.read(geoRepositoryProvider).zip(zip);
    if (!mounted) return;
    setState(() => _locationLabel = rg?.label);
  }

  void _onDistanceChanged(double v) {
    setState(() => _distanceMi = v);
    _rebuildSoon();
  }

  /// Map an [OpenMat] to the presentational [SessionRowData] used by rows.
  SessionRowData _toRow(OpenMat mat) {
    return SessionRowData(
      id: mat.id,
      gymName: mat.gymName ?? mat.title,
      giType: mat.giType,
      expLevel: _expLevel(mat.skillLevel),
      time: mat.startLabel,
      day: mat.dayName,
      distance: mat.distanceKm != null
          ? '${(mat.distanceKm! / 1.60934).toStringAsFixed(1)} mi'
          : '',
      fee: (mat.feeCents ?? 0) / 100,
      unverified: !mat.verified,
    );
  }

  static String _expLevel(String skillLevel) {
    switch (skillLevel) {
      case 'beginner':
        return 'beg';
      case 'intermediate':
        return 'int';
      case 'advanced':
        return 'adv';
      default:
        return 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<AppTokens>()!;
    return _buildGlass(t);
  }

  // ── When option chip (shared) ────────────────────────────────────────────
  Widget _whenOption(AppTokens t, {required Key key, required String label, required VoidCallback onTap, required bool active}) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? t.primary.withValues(alpha: 0.09) : t.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? t.primary.withValues(alpha: 0.33) : t.borderHi,
            width: 1.5,
          ),
        ),
        child: Text(label, style: t.miniStyle.copyWith(
          color: active ? t.primary : t.body,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        )),
      ),
    );
  }

  List<Widget> _whenOptions(AppTokens t) {
    final now = DateTime.now();
    return [
      _whenOption(t, key: const Key('when-week'), label: 'This week', active: _whenLabel == 'This week', onTap: () => _setWhen(WhenRange.thisWeek(now), 'This week')),
      _whenOption(t, key: const Key('when-weekend'), label: 'This weekend', active: _whenLabel == 'This weekend', onTap: () => _setWhen(WhenRange.thisWeekend(now), 'This weekend')),
      _whenOption(t, key: const Key('when-month'), label: 'This month', active: _whenLabel == 'This month', onTap: () => _setWhen(WhenRange.thisMonth(now), 'This month')),
      _whenOption(t, key: const Key('when-date'), label: 'Pick a date', active: _when != null && !['This week', 'This weekend', 'This month', 'Any time'].contains(_whenLabel), onTap: _pickDate),
    ];
  }

  Widget _buildGlass(AppTokens t) {
    final results = ref.watch(searchResultsProvider(_query));
    final whenOptions = _whenOptions(t);
    final filters = [
      (id: 'gi', label: 'Gi', color: t.gi),
      (id: 'nogi', label: 'No-Gi', color: t.noGi),
      (id: 'both', label: 'Gi · No-Gi', color: t.both),
      (id: 'free', label: 'Free', color: t.green),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Find a Mat', style: t.h1Style),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(13)),
                    child: Icon(LucideIcons.mapPin, size: 18, color: t.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 52,
                decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(LucideIcons.search, size: 18, color: t.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: t.h2Style.copyWith(fontSize: 15, color: t.text),
                      decoration: InputDecoration(
                        hintText: _locationLabel ?? 'Los Angeles, CA',
                        hintStyle: t.h2Style.copyWith(fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => _onTextChanged(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _useGps,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(children: [
                        Icon(LucideIcons.locateFixed, size: 13, color: t.primary),
                        const SizedBox(width: 4),
                        Text(_locationLabel ?? 'GPS', style: t.miniStyle.copyWith(color: t.primary, fontSize: 10)),
                      ]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                height: 52,
                decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(LucideIcons.mapPin, size: 18, color: t.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('search-zip'),
                      controller: _zipCtrl,
                      style: t.h2Style.copyWith(fontSize: 15, color: t.text),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'ZIP code',
                        hintStyle: t.h2Style.copyWith(fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => _onZipChanged(),
                      onSubmitted: (_) {
                        _rebuildQuery();
                        _resolveZipLabel();
                      },
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: filters.length,
              itemBuilder: (_, i) {
                final f = filters[i];
                final on = _filters.contains(f.id);
                return GestureDetector(
                  onTap: () => _toggleFilter(f.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: on ? f.color.withValues(alpha: 0.09) : t.bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: on ? f.color.withValues(alpha: 0.33) : t.borderHi,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      if (on) ...[
                        Icon(LucideIcons.check, size: 13, color: f.color),
                        const SizedBox(width: 5),
                      ],
                      Text(f.label, style: t.miniStyle.copyWith(
                        color: on ? f.color : t.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      )),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WHEN', style: t.miniStyle.copyWith(color: t.muted, fontSize: 10)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(LucideIcons.calendar, size: 15, color: t.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_whenLabel, style: t.h2Style.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ]),
              )),
              const SizedBox(width: 12),
              Expanded(child: Container(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [BoxShadow(color: const Color(0xFF14151A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('WITHIN', style: t.miniStyle.copyWith(color: t.muted, fontSize: 10)),
                    const Spacer(),
                    Text('${_distanceMi.toStringAsFixed(0)} mi', style: t.numStyle.copyWith(fontSize: 14, color: t.text)),
                  ]),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: t.primary,
                      inactiveTrackColor: t.panel,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      trackHeight: 6,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: SizedBox(
                      height: 20,
                      child: Slider(
                        value: _distanceMi,
                        min: 1,
                        max: 100,
                        onChanged: _onDistanceChanged,
                      ),
                    ),
                  ),
                ]),
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: whenOptions.length,
                itemBuilder: (_, i) => whenOptions[i],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(text: TextSpan(children: [
                  TextSpan(text: '${results.asData?.value.length ?? 0}', style: t.h2Style.copyWith(color: t.primary)),
                  TextSpan(text: (results.asData?.value.length ?? 0) == 1 ? ' Session' : ' Sessions', style: t.h2Style),
                ])),
                const Spacer(),
                GestureDetector(
                  key: const Key('save-default-filters'),
                  onTap: _saveAsDefault,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.bookmark, size: 13, color: t.primary),
                      const SizedBox(width: 4),
                      Text('Save', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700, fontSize: 11)),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Map view', style: t.miniStyle.copyWith(color: t.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text("Couldn't load results", style: t.bodyStyle.copyWith(color: t.muted)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.mapPin,
                    title: _locationLabel != null ? 'No open mats found in $_locationLabel' : 'No open mats found',
                    subtitle: 'Try a different area, widen the radius, or clear filters.',
                  );
                }
                // Sparse results (1-2 matches): pad the screen with a "Gyms
                // near you" section so it doesn't read as dead space. 3+
                // results already fill the screen on their own.
                if (list.length < 3) {
                  final gyms = distinctGymsFromOpenMats(list);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final mat in list) ...[
                          SessionRow(
                            session: _toRow(mat),
                            onTap: () => context.go('/open-mat/${mat.id}'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (gyms.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('GYMS NEAR YOU', style: t.miniStyle.copyWith(color: t.primary, fontSize: 11)),
                          const SizedBox(height: 3),
                          Text('More places to roll', style: t.h2Style),
                          const SizedBox(height: 12),
                          for (final gym in gyms) ...[
                            GymCard(gym: gym),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => SessionRow(
                    session: _toRow(list[i]),
                    onTap: () => context.go('/open-mat/${list[i].id}'),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
