# Role Switch Menu Item Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user switch between the practitioner and gym-owner experiences from a menu item; the router already swaps the nav shell based on `user.role`.

**Architecture:** A small pure helper computes the toggle target + label from the current role. `setRole()` already exists on `AuthStateNotifier` and PUTs `{role}` to the API. The Settings screen (both themes) and the Profile settings card get a menu tile that calls `setRole()` and navigates to the correct shell root.

**Tech Stack:** Flutter/Dart, Riverpod, go_router.

---

### Task 1: Add a pure role-toggle helper

**Files:**
- Create: `apps/mobile/lib/features/settings/role_toggle.dart`
- Test: `apps/mobile/test/role_toggle_test.dart`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/role_toggle_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/features/settings/role_toggle.dart';

void main() {
  test('practitioner toggles to gym_owner', () {
    final t = roleToggle('practitioner');
    expect(t.targetRole, 'gym_owner');
    expect(t.label, 'Switch to Gym Owner');
    expect(t.destination, '/owner/dashboard');
  });

  test('gym_owner toggles to practitioner', () {
    final t = roleToggle('gym_owner');
    expect(t.targetRole, 'practitioner');
    expect(t.label, 'Switch to Practitioner');
    expect(t.destination, '/');
  });

  test('null/unknown role defaults to becoming a gym owner', () {
    expect(roleToggle(null).targetRole, 'gym_owner');
    expect(roleToggle('admin').targetRole, 'gym_owner');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/role_toggle_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the helper**

Create `apps/mobile/lib/features/settings/role_toggle.dart`:

```dart
class RoleToggle {
  final String targetRole;
  final String label;
  final String destination;
  const RoleToggle(this.targetRole, this.label, this.destination);
}

/// Given the current role, compute what a single "switch role" tap should do.
/// Only practitioner and gym_owner participate; anything else becomes a gym owner.
RoleToggle roleToggle(String? currentRole) {
  if (currentRole == 'gym_owner') {
    return const RoleToggle('practitioner', 'Switch to Practitioner', '/');
  }
  return const RoleToggle('gym_owner', 'Switch to Gym Owner', '/owner/dashboard');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/role_toggle_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/settings/role_toggle.dart apps/mobile/test/role_toggle_test.dart
git commit -m "feat(mobile): add role-toggle helper"
```

---

### Task 2: Add the switch tile to the Settings screen (both themes)

**Files:**
- Modify: `apps/mobile/lib/features/settings/screens/settings_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `settings_screen.dart` add:

```dart
import '../role_toggle.dart';
```

- [ ] **Step 2: Add the tile to `_SportSettings`**

In `_SportSettings.build`, insert this block into the `ListView` immediately before the "Sign Out" `Container` (the one with `LucideIcons.logOut`):

```dart
              Builder(builder: (ctx) {
                final role = ref.watch(authStateProvider).user?.role;
                final toggle = roleToggle(role);
                return Container(
                  color: t.surface,
                  child: ListTile(
                    leading: Icon(LucideIcons.repeat, color: t.muted, size: 18),
                    title: Text(toggle.label, style: t.bodyStyle),
                    trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.faint),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await ref.read(authStateProvider.notifier).setRole(toggle.targetRole);
                      if (ctx.mounted) ctx.go(toggle.destination);
                    },
                  ),
                );
              }),
              Divider(height: 1, color: t.border),
```

- [ ] **Step 3: Add the tile to `_GlassSettings`**

In `_GlassSettings.build`, inside the settings `Column`, insert immediately before the "Sign Out" `ListTile` (the `LucideIcons.logOut` one):

```dart
                Builder(builder: (ctx) {
                  final role = ref.watch(authStateProvider).user?.role;
                  final toggle = roleToggle(role);
                  return ListTile(
                    leading: Icon(LucideIcons.repeat, color: t.muted),
                    title: Text(toggle.label, style: t.bodyStyle),
                    trailing: Icon(LucideIcons.chevronRight, size: 16, color: t.muted),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await ref.read(authStateProvider.notifier).setRole(toggle.targetRole);
                      if (ctx.mounted) ctx.go(toggle.destination);
                    },
                  );
                }),
                Divider(height: 1, color: t.border),
```

> `authStateProvider` and `HapticFeedback` are already imported in this file; `ref` is a field on both `_SportSettings` and `_GlassSettings`.

- [ ] **Step 4: Analyze**

Run: `cd apps/mobile && flutter analyze lib/features/settings/screens/settings_screen.dart`
Expected: "No issues found!" (or only pre-existing warnings).

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/features/settings/screens/settings_screen.dart
git commit -m "feat(mobile): add role switch tile to settings"
```

---

### Task 3: Replace the Profile "Gym Owner Panel" tile with a role switch

**Files:**
- Modify: `apps/mobile/lib/features/profile/screens/profile_screen.dart:331-336`

- [ ] **Step 1: Add the import**

At the top of `profile_screen.dart` add:

```dart
import '../../settings/role_toggle.dart';
import 'package:flutter/services.dart';
```

- [ ] **Step 2: Replace the "Gym Owner Panel" ListTile in `_GlassProfile`**

Replace this existing tile:

```dart
                  ListTile(
                    leading: Icon(LucideIcons.store, color: t.muted),
                    title: Text('Gym Owner Panel', style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                    trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                    onTap: () => context.go('/owner/dashboard'),
                  ),
```

with:

```dart
                  Builder(builder: (ctx) {
                    final role = ref.watch(authStateProvider).user?.role;
                    final toggle = roleToggle(role);
                    return ListTile(
                      leading: Icon(LucideIcons.repeat, color: t.muted),
                      title: Text(toggle.label, style: t.bodyStyle.copyWith(fontWeight: FontWeight.w600, color: t.text)),
                      trailing: Icon(LucideIcons.chevronRight, size: 15, color: t.faint),
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await ref.read(authStateProvider.notifier).setRole(toggle.targetRole);
                        if (ctx.mounted) ctx.go(toggle.destination);
                      },
                    );
                  }),
```

> `_GlassProfile` already receives `ref` as a field, and `authStateProvider` is already imported in this file.

- [ ] **Step 3: Analyze**

Run: `cd apps/mobile && flutter analyze lib/features/profile/screens/profile_screen.dart`
Expected: "No issues found!" (or only pre-existing warnings).

- [ ] **Step 4: Commit**

```bash
git add apps/mobile/lib/features/profile/screens/profile_screen.dart
git commit -m "feat(mobile): profile role-switch tile"
```

---

## Self-Review notes
- Spec section D covered: helper (T1), settings tiles both themes (T2), profile shortcut (T3).
- Consistent API: `roleToggle(role)` → `{targetRole, label, destination}` used identically in all three UI sites.
- Router redirect in `app/router.dart` already routes to the correct shell once `user.role` updates via `setRole()`; the explicit `ctx.go(destination)` forces the shell to rebuild immediately.
