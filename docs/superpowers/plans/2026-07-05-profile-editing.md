# Profile Editing (city/state + structured weight) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users edit city, state, gender, and a structured weight (numeric value with lb/kg unit) plus a manually-picked IBJJF division (gender- and gi/no-gi-aware). Weight value and division are stored **independently** — no auto-classification.

**Architecture:** Add enums + an IBJJF reference table + new optional `User` fields to `packages/contract` (the single source of truth). The API's user repository already `$set`-patches `Partial<User>`, so new fields persist with no repo change; a facade test locks that behavior. The Flutter `UserProfile` model and `EditProfileScreen` gain the new fields; a mirrored Dart reference table drives the division picker.

**Tech Stack:** TypeBox (contract), Elysia/Bun (API), Bun test, Flutter/Dart, Riverpod.

---

### Task 1: Add `Gender` and `WeightDivision` enums to the contract

**Files:**
- Create: `packages/contract/src/enums/gender.mts`
- Create: `packages/contract/src/enums/weight-division.mts`
- Modify: `packages/contract/src/enums/index.mts`
- Test: `packages/contract/test/weight-enums.test.mts`

- [ ] **Step 1: Write the failing test**

Create `packages/contract/test/weight-enums.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { Gender } from "../src/enums/gender.mts";
import { WeightDivision } from "../src/enums/weight-division.mts";

describe("Gender enum", () => {
  it("accepts male and female", () => {
    expect(Value.Check(Gender, "male")).toBe(true);
    expect(Value.Check(Gender, "female")).toBe(true);
  });
  it("rejects other values", () => {
    expect(Value.Check(Gender, "other")).toBe(false);
  });
});

describe("WeightDivision enum", () => {
  it("accepts feather and ultra_heavy", () => {
    expect(Value.Check(WeightDivision, "feather")).toBe(true);
    expect(Value.Check(WeightDivision, "ultra_heavy")).toBe(true);
  });
  it("rejects unknown division", () => {
    expect(Value.Check(WeightDivision, "cruiserweight")).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/weight-enums.test.mts`
Expected: FAIL — cannot resolve `../src/enums/gender.mts`.

- [ ] **Step 3: Create the enums**

Create `packages/contract/src/enums/gender.mts`:

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const Gender = t.Union([t.Literal("male"), t.Literal("female")], { $id: "Gender" });
export type Gender = Static<typeof Gender>;
```

Create `packages/contract/src/enums/weight-division.mts`:

```typescript
import { type Static, Type as t } from "@sinclair/typebox";

export const WeightDivision = t.Union(
  [
    t.Literal("rooster"),
    t.Literal("light_feather"),
    t.Literal("feather"),
    t.Literal("light"),
    t.Literal("middle"),
    t.Literal("medium_heavy"),
    t.Literal("heavy"),
    t.Literal("super_heavy"),
    t.Literal("ultra_heavy"),
  ],
  { $id: "WeightDivision" },
);
export type WeightDivision = Static<typeof WeightDivision>;
```

Add to `packages/contract/src/enums/index.mts` (follow the existing export style in that file):

```typescript
export * from "./gender.mjs";
export * from "./weight-division.mjs";
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/weight-enums.test.mts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/enums packages/contract/test/weight-enums.test.mts
git commit -m "feat(contract): add Gender and WeightDivision enums"
```

---

### Task 2: Add the IBJJF weight-class reference table (contract)

**Files:**
- Create: `packages/contract/src/reference/ibjjf-weight-classes.mts`
- Modify: `packages/contract/src/index.mts` (add export)
- Test: `packages/contract/test/ibjjf-weight-classes.test.mts`

- [ ] **Step 1: Write the failing test**

Create `packages/contract/test/ibjjf-weight-classes.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import { IBJJF_WEIGHT_CLASSES, divisionsFor } from "../src/reference/ibjjf-weight-classes.mts";

describe("IBJJF weight classes", () => {
  it("male gi feather upper limit is 70 kg", () => {
    const row = IBJJF_WEIGHT_CLASSES.male.gi.find((r) => r.division === "feather");
    expect(row?.maxKg).toBe(70);
  });

  it("female nogi rooster upper limit is 46.5 kg", () => {
    const row = IBJJF_WEIGHT_CLASSES.female.nogi.find((r) => r.division === "rooster");
    expect(row?.maxKg).toBe(46.5);
  });

  it("ultra_heavy has no upper limit (null)", () => {
    const row = IBJJF_WEIGHT_CLASSES.male.gi.find((r) => r.division === "ultra_heavy");
    expect(row?.maxKg).toBeNull();
  });

  it("divisionsFor(female, gi) excludes ultra_heavy (7 divisions, super_heavy is open)", () => {
    const list = divisionsFor("female", "gi");
    expect(list.map((r) => r.division)).not.toContain("ultra_heavy");
    expect(list.length).toBe(7);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/ibjjf-weight-classes.test.mts`
Expected: FAIL — module not found.

- [ ] **Step 3: Create the reference table**

Create `packages/contract/src/reference/ibjjf-weight-classes.mts`:

```typescript
import type { Gender } from "../enums/gender.mjs";
import type { WeightDivision } from "../enums/weight-division.mjs";

export type GiContext = "gi" | "nogi";

export interface WeightClassRow {
  division: WeightDivision;
  label: string;
  maxKg: number | null; // null => no upper limit (open class)
  maxLb: number | null;
}

export const IBJJF_WEIGHT_CLASSES: Record<Gender, Record<GiContext, readonly WeightClassRow[]>> = {
  male: {
    gi: [
      { division: "rooster", label: "Rooster", maxKg: 57.5, maxLb: 126.8 },
      { division: "light_feather", label: "Light Feather", maxKg: 64, maxLb: 141.1 },
      { division: "feather", label: "Feather", maxKg: 70, maxLb: 154.3 },
      { division: "light", label: "Light", maxKg: 76, maxLb: 167.6 },
      { division: "middle", label: "Middle", maxKg: 82.3, maxLb: 181.4 },
      { division: "medium_heavy", label: "Medium Heavy", maxKg: 88.3, maxLb: 194.7 },
      { division: "heavy", label: "Heavy", maxKg: 94.3, maxLb: 207.9 },
      { division: "super_heavy", label: "Super Heavy", maxKg: 100.5, maxLb: 221.6 },
      { division: "ultra_heavy", label: "Ultra Heavy", maxKg: null, maxLb: null },
    ],
    nogi: [
      { division: "rooster", label: "Rooster", maxKg: 55.5, maxLb: 122.4 },
      { division: "light_feather", label: "Light Feather", maxKg: 61.5, maxLb: 135.6 },
      { division: "feather", label: "Feather", maxKg: 67.5, maxLb: 148.8 },
      { division: "light", label: "Light", maxKg: 73.5, maxLb: 162.0 },
      { division: "middle", label: "Middle", maxKg: 79.5, maxLb: 175.3 },
      { division: "medium_heavy", label: "Medium Heavy", maxKg: 85.5, maxLb: 188.5 },
      { division: "heavy", label: "Heavy", maxKg: 91.5, maxLb: 201.7 },
      { division: "super_heavy", label: "Super Heavy", maxKg: 97.5, maxLb: 215.0 },
      { division: "ultra_heavy", label: "Ultra Heavy", maxKg: null, maxLb: null },
    ],
  },
  female: {
    gi: [
      { division: "rooster", label: "Rooster", maxKg: 48.5, maxLb: 106.9 },
      { division: "light_feather", label: "Light Feather", maxKg: 53.5, maxLb: 117.9 },
      { division: "feather", label: "Feather", maxKg: 58.5, maxLb: 129.0 },
      { division: "light", label: "Light", maxKg: 64, maxLb: 141.1 },
      { division: "middle", label: "Middle", maxKg: 69, maxLb: 152.1 },
      { division: "medium_heavy", label: "Medium Heavy", maxKg: 74, maxLb: 163.1 },
      { division: "heavy", label: "Heavy", maxKg: 79.3, maxLb: 174.8 },
      { division: "super_heavy", label: "Super Heavy", maxKg: null, maxLb: null },
    ],
    nogi: [
      { division: "rooster", label: "Rooster", maxKg: 46.5, maxLb: 102.5 },
      { division: "light_feather", label: "Light Feather", maxKg: 51.5, maxLb: 113.5 },
      { division: "feather", label: "Feather", maxKg: 56.5, maxLb: 124.6 },
      { division: "light", label: "Light", maxKg: 61.5, maxLb: 135.6 },
      { division: "middle", label: "Middle", maxKg: 66.5, maxLb: 146.6 },
      { division: "medium_heavy", label: "Medium Heavy", maxKg: 71.5, maxLb: 157.6 },
      { division: "heavy", label: "Heavy", maxKg: 76.5, maxLb: 168.7 },
      { division: "super_heavy", label: "Super Heavy", maxKg: null, maxLb: null },
    ],
  },
};

export function divisionsFor(gender: Gender, context: GiContext): readonly WeightClassRow[] {
  return IBJJF_WEIGHT_CLASSES[gender][context];
}
```

Add to `packages/contract/src/index.mts` (match existing export style):

```typescript
export * from "./reference/ibjjf-weight-classes.mjs";
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/ibjjf-weight-classes.test.mts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/contract/src/reference packages/contract/src/index.mts packages/contract/test/ibjjf-weight-classes.test.mts
git commit -m "feat(contract): add IBJJF weight-class reference table"
```

---

### Task 3: Add new fields to `User` and `UpdateUserRequest`

**Files:**
- Modify: `packages/contract/src/schemas/user.mts:15-32`
- Modify: `packages/contract/src/schemas/requests/user-requests.mts:6-18`
- Test: `packages/contract/test/user-profile-fields.test.mts`

- [ ] **Step 1: Write the failing test**

Create `packages/contract/test/user-profile-fields.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import { Value } from "@sinclair/typebox/value";
import { UpdateUserRequest } from "../src/schemas/requests/user-requests.mts";

describe("UpdateUserRequest new fields", () => {
  it("accepts city, state, gender, weightValue, weightUnit, weightDivision, weightDivisionContext", () => {
    const patch = {
      city: "Austin",
      state: "TX",
      gender: "male",
      weightValue: 172,
      weightUnit: "lb",
      weightDivision: "light",
      weightDivisionContext: "nogi",
    };
    expect(Value.Check(UpdateUserRequest, patch)).toBe(true);
  });

  it("rejects an invalid weightUnit", () => {
    expect(Value.Check(UpdateUserRequest, { weightUnit: "stone" })).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/contract && bun test test/user-profile-fields.test.mts`
Expected: FAIL — `weightValue` etc. rejected (not yet in schema).

- [ ] **Step 3: Extend the schemas**

In `packages/contract/src/schemas/user.mts`, add imports at the top (after the existing enum imports):

```typescript
import { Gender } from "../enums/gender.mts";
import { WeightDivision } from "../enums/weight-division.mts";
```

Then inside the `User` object (after the existing `weight: t.Optional(t.String()),` line) add:

```typescript
    city: t.Optional(t.String()),
    state: t.Optional(t.String()),
    gender: t.Optional(Gender),
    weightValue: t.Optional(t.Number()),
    weightUnit: t.Optional(t.Union([t.Literal("lb"), t.Literal("kg")])),
    weightDivision: t.Optional(WeightDivision),
    weightDivisionContext: t.Optional(t.Union([t.Literal("gi"), t.Literal("nogi")])),
```

In `packages/contract/src/schemas/requests/user-requests.mts`, add imports:

```typescript
import { Gender } from "../../enums/gender.mts";
import { WeightDivision } from "../../enums/weight-division.mts";
```

Then inside the `UpdateUserRequest` `t.Object({...})` (after `weight: t.String(),`) add:

```typescript
    city: t.String(),
    state: t.String(),
    gender: Gender,
    weightValue: t.Number(),
    weightUnit: t.Union([t.Literal("lb"), t.Literal("kg")]),
    weightDivision: WeightDivision,
    weightDivisionContext: t.Union([t.Literal("gi"), t.Literal("nogi")]),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/contract && bun test test/user-profile-fields.test.mts`
Expected: PASS (2 tests).

- [ ] **Step 5: Type-check the contract package**

Run: `cd packages/contract && bun run type-check`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add packages/contract/src/schemas packages/contract/test/user-profile-fields.test.mts
git commit -m "feat(contract): add city/state/gender/structured-weight to User"
```

---

### Task 4: Lock the API persistence of new fields (facade test)

**Files:**
- Test: `apps/api/test/user-facade-profile.test.mts`

The repository `update(id, patch)` already `$set`s a `Partial<User>`, and `UserFacade.updateProfile` forwards the patch. This test proves the new fields reach the repository unchanged (no dropping).

- [ ] **Step 1: Write the test**

Create `apps/api/test/user-facade-profile.test.mts`:

```typescript
import { describe, expect, it } from "bun:test";
import type { UpdateUserRequest, User } from "@bjj/contract";
import { UserFacade } from "../src/facades/user.facade.mts";

function stubUsers(stored: User) {
  let lastPatch: Partial<User> | null = null;
  const repo = {
    findById: async (_id: string): Promise<User | null> => ({ ...stored, ...lastPatch }),
    upsertByAuth0Id: async (): Promise<User> => stored,
    insert: async (u: User): Promise<User> => u,
    update: async (_id: string, patch: Partial<User>): Promise<User | null> => {
      lastPatch = patch;
      return { ...stored, ...patch };
    },
  };
  return { repo, getPatch: (): Partial<User> | null => lastPatch };
}

describe("UserFacade.updateProfile", () => {
  it("forwards city/state/gender/weight fields to the repository", async () => {
    const base: User = { id: "u1", email: "a@b.co", displayName: "A" };
    const { repo, getPatch } = stubUsers(base);
    const facade = new UserFacade(repo);
    const patch: UpdateUserRequest = {
      city: "Austin",
      state: "TX",
      gender: "male",
      weightValue: 172,
      weightUnit: "lb",
      weightDivision: "light",
      weightDivisionContext: "nogi",
    };
    const result = await facade.updateProfile("u1", patch);
    expect(getPatch()).toMatchObject(patch);
    expect(result.city).toBe("Austin");
    expect(result.weightDivision).toBe("light");
  });
});
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd apps/api && bun test test/user-facade-profile.test.mts`
Expected: PASS (1 test). (Depends on Task 3's contract types being built — run `bun install` at repo root first if `@bjj/contract` types are stale.)

- [ ] **Step 3: Commit**

```bash
git add apps/api/test/user-facade-profile.test.mts
git commit -m "test(api): lock profile field persistence through UserFacade"
```

---

### Task 5: Extend the Flutter `UserProfile` model

**Files:**
- Modify: `apps/mobile/lib/core/auth/auth_service.dart:45-96`
- Test: `apps/mobile/test/user_profile_model_test.dart`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/user_profile_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/auth/auth_service.dart';

void main() {
  test('UserProfile round-trips the new profile fields', () {
    final json = {
      'id': 'u1',
      'email': 'a@b.co',
      'displayName': 'A',
      'city': 'Austin',
      'state': 'TX',
      'gender': 'male',
      'weightValue': 172.0,
      'weightUnit': 'lb',
      'weightDivision': 'light',
      'weightDivisionContext': 'nogi',
    };
    final p = UserProfile.fromJson(json);
    expect(p.city, 'Austin');
    expect(p.state, 'TX');
    expect(p.gender, 'male');
    expect(p.weightValue, 172.0);
    expect(p.weightUnit, 'lb');
    expect(p.weightDivision, 'light');
    expect(p.weightDivisionContext, 'nogi');
    expect(p.toJson()['city'], 'Austin');
    expect(p.toJson()['weightDivision'], 'light');
  });
}
```

> Note: the import package name is `bjj_open_mat` (see `apps/mobile/pubspec.yaml` `name:`). If it differs, use that value.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/user_profile_model_test.dart`
Expected: FAIL — `city` getter undefined.

- [ ] **Step 3: Add the fields**

In `apps/mobile/lib/core/auth/auth_service.dart`, extend `UserProfile`:

Add fields (after `final String? homeGymId;`):

```dart
  final String? city;
  final String? state;
  final String? gender;
  final double? weightValue;
  final String? weightUnit;
  final String? weightDivision;
  final String? weightDivisionContext;
```

Add to the constructor (after `this.homeGymId,`):

```dart
    this.city,
    this.state,
    this.gender,
    this.weightValue,
    this.weightUnit,
    this.weightDivision,
    this.weightDivisionContext,
```

Add to `fromJson` (after `homeGymId: json['homeGymId'] as String?,`):

```dart
      city: json['city'] as String?,
      state: json['state'] as String?,
      gender: json['gender'] as String?,
      weightValue: (json['weightValue'] as num?)?.toDouble(),
      weightUnit: json['weightUnit'] as String?,
      weightDivision: json['weightDivision'] as String?,
      weightDivisionContext: json['weightDivisionContext'] as String?,
```

Add to `toJson` (after `'homeGymId': homeGymId,`):

```dart
    'city': city,
    'state': state,
    'gender': gender,
    'weightValue': weightValue,
    'weightUnit': weightUnit,
    'weightDivision': weightDivision,
    'weightDivisionContext': weightDivisionContext,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/user_profile_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/core/auth/auth_service.dart apps/mobile/test/user_profile_model_test.dart
git commit -m "feat(mobile): add profile fields to UserProfile model"
```

---

### Task 6: Add the Dart IBJJF reference table

**Files:**
- Create: `apps/mobile/lib/core/reference/ibjjf_weight_classes.dart`
- Test: `apps/mobile/test/ibjjf_weight_classes_test.dart`

- [ ] **Step 1: Write the failing test**

Create `apps/mobile/test/ibjjf_weight_classes_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bjj_open_mat/core/reference/ibjjf_weight_classes.dart';

void main() {
  test('male gi feather max is 70 kg', () {
    final row = divisionsFor('male', 'gi').firstWhere((r) => r.division == 'feather');
    expect(row.maxKg, 70);
  });

  test('female gi list has 7 divisions and no ultra_heavy', () {
    final list = divisionsFor('female', 'gi');
    expect(list.length, 7);
    expect(list.any((r) => r.division == 'ultra_heavy'), false);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/mobile && flutter test test/ibjjf_weight_classes_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Create the Dart reference**

Create `apps/mobile/lib/core/reference/ibjjf_weight_classes.dart`:

```dart
class WeightClassRow {
  final String division;
  final String label;
  final double? maxKg; // null => open class
  final double? maxLb;
  const WeightClassRow(this.division, this.label, this.maxKg, this.maxLb);
}

const Map<String, Map<String, List<WeightClassRow>>> ibjjfWeightClasses = {
  'male': {
    'gi': [
      WeightClassRow('rooster', 'Rooster', 57.5, 126.8),
      WeightClassRow('light_feather', 'Light Feather', 64, 141.1),
      WeightClassRow('feather', 'Feather', 70, 154.3),
      WeightClassRow('light', 'Light', 76, 167.6),
      WeightClassRow('middle', 'Middle', 82.3, 181.4),
      WeightClassRow('medium_heavy', 'Medium Heavy', 88.3, 194.7),
      WeightClassRow('heavy', 'Heavy', 94.3, 207.9),
      WeightClassRow('super_heavy', 'Super Heavy', 100.5, 221.6),
      WeightClassRow('ultra_heavy', 'Ultra Heavy', null, null),
    ],
    'nogi': [
      WeightClassRow('rooster', 'Rooster', 55.5, 122.4),
      WeightClassRow('light_feather', 'Light Feather', 61.5, 135.6),
      WeightClassRow('feather', 'Feather', 67.5, 148.8),
      WeightClassRow('light', 'Light', 73.5, 162.0),
      WeightClassRow('middle', 'Middle', 79.5, 175.3),
      WeightClassRow('medium_heavy', 'Medium Heavy', 85.5, 188.5),
      WeightClassRow('heavy', 'Heavy', 91.5, 201.7),
      WeightClassRow('super_heavy', 'Super Heavy', 97.5, 215.0),
      WeightClassRow('ultra_heavy', 'Ultra Heavy', null, null),
    ],
  },
  'female': {
    'gi': [
      WeightClassRow('rooster', 'Rooster', 48.5, 106.9),
      WeightClassRow('light_feather', 'Light Feather', 53.5, 117.9),
      WeightClassRow('feather', 'Feather', 58.5, 129.0),
      WeightClassRow('light', 'Light', 64, 141.1),
      WeightClassRow('middle', 'Middle', 69, 152.1),
      WeightClassRow('medium_heavy', 'Medium Heavy', 74, 163.1),
      WeightClassRow('heavy', 'Heavy', 79.3, 174.8),
      WeightClassRow('super_heavy', 'Super Heavy', null, null),
    ],
    'nogi': [
      WeightClassRow('rooster', 'Rooster', 46.5, 102.5),
      WeightClassRow('light_feather', 'Light Feather', 51.5, 113.5),
      WeightClassRow('feather', 'Feather', 56.5, 124.6),
      WeightClassRow('light', 'Light', 61.5, 135.6),
      WeightClassRow('middle', 'Middle', 66.5, 146.6),
      WeightClassRow('medium_heavy', 'Medium Heavy', 71.5, 157.6),
      WeightClassRow('heavy', 'Heavy', 76.5, 168.7),
      WeightClassRow('super_heavy', 'Super Heavy', null, null),
    ],
  },
};

List<WeightClassRow> divisionsFor(String gender, String context) {
  return ibjjfWeightClasses[gender]?[context] ?? const [];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/mobile && flutter test test/ibjjf_weight_classes_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mobile/lib/core/reference/ibjjf_weight_classes.dart apps/mobile/test/ibjjf_weight_classes_test.dart
git commit -m "feat(mobile): add Dart IBJJF weight-class reference"
```

---

### Task 7: Wire the new fields into `EditProfileScreen`

**Files:**
- Modify: `apps/mobile/lib/features/profile/screens/edit_profile_screen.dart`

- [ ] **Step 1: Add state + controllers**

In `_EditProfileScreenState`, add fields after `String _selectedBelt = 'white';`:

```dart
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _weightValueController;
  String _gender = 'male';
  String _weightUnit = 'lb';
  String _divisionContext = 'nogi';
  String? _weightDivision;
```

In `initState`, after the existing controller setup, add:

```dart
    _cityController = TextEditingController(text: user?.city ?? '');
    _stateController = TextEditingController(text: user?.state ?? '');
    _weightValueController =
        TextEditingController(text: user?.weightValue?.toString() ?? '');
    _gender = user?.gender ?? 'male';
    _weightUnit = user?.weightUnit ?? 'lb';
    _divisionContext = user?.weightDivisionContext ?? 'nogi';
    _weightDivision = user?.weightDivision;
```

In `dispose`, add:

```dart
    _cityController.dispose();
    _stateController.dispose();
    _weightValueController.dispose();
```

- [ ] **Step 2: Extend the save payload**

Replace the `updateProfile` map in `_save()` with:

```dart
    await ref.read(authStateProvider.notifier).updateProfile({
      'displayName': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'beltRank': _selectedBelt,
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'gender': _gender,
      if (double.tryParse(_weightValueController.text.trim()) != null)
        'weightValue': double.parse(_weightValueController.text.trim()),
      'weightUnit': _weightUnit,
      'weightDivisionContext': _divisionContext,
      if (_weightDivision != null) 'weightDivision': _weightDivision,
    });
```

- [ ] **Step 3: Add the import**

At the top of the file add:

```dart
import '../../../core/reference/ibjjf_weight_classes.dart';
```

- [ ] **Step 4: Add the new form fields**

In `build`, inside the `ListView`, after the existing Weight `TextField` (the `_weightController` one), insert:

```dart
          const SizedBox(height: StitchTokens.md),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
            ),
            const SizedBox(width: StitchTokens.md),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _stateController,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'State', counterText: ''),
              ),
            ),
          ]),
          const SizedBox(height: StitchTokens.md),
          Text('Gender', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'male', label: Text('Male')),
              ButtonSegment(value: 'female', label: Text('Female')),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() {
              _gender = s.first;
              _weightDivision = null; // division set differs by gender
            }),
          ),
          const SizedBox(height: StitchTokens.md),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _weightValueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight'),
              ),
            ),
            const SizedBox(width: StitchTokens.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lb', label: Text('lb')),
                ButtonSegment(value: 'kg', label: Text('kg')),
              ],
              selected: {_weightUnit},
              onSelectionChanged: (s) => setState(() => _weightUnit = s.first),
            ),
          ]),
          const SizedBox(height: StitchTokens.md),
          Text('Division', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StitchTokens.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gi', label: Text('Gi')),
              ButtonSegment(value: 'nogi', label: Text('No-Gi')),
            ],
            selected: {_divisionContext},
            onSelectionChanged: (s) => setState(() {
              _divisionContext = s.first;
              _weightDivision = null;
            }),
          ),
          const SizedBox(height: StitchTokens.sm),
          DropdownButton<String>(
            isExpanded: true,
            value: _weightDivision,
            hint: const Text('Select division'),
            items: divisionsFor(_gender, _divisionContext)
                .map((r) => DropdownMenuItem(value: r.division, child: Text(r.label)))
                .toList(),
            onChanged: (v) => setState(() => _weightDivision = v),
          ),
```

- [ ] **Step 5: Analyze**

Run: `cd apps/mobile && flutter analyze lib/features/profile/screens/edit_profile_screen.dart`
Expected: "No issues found!" (or only pre-existing warnings).

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/lib/features/profile/screens/edit_profile_screen.dart
git commit -m "feat(mobile): edit city/state/gender/weight+division in profile"
```

---

## Self-Review notes
- Spec section E fully covered: enums (T1), reference table (T2), User/UpdateUserRequest (T3), persistence lock (T4), Dart model (T5), Dart reference (T6), edit UI (T7).
- Type names consistent across tasks: `WeightClassRow`, `divisionsFor(gender, context)`, `weightValue/weightUnit/weightDivision/weightDivisionContext`.
- Legacy free-text `weight` string field left intact for backward compatibility (additive change).
- After Task 3, run `bun install` at repo root if the API/mobile builds don't see the new `@bjj/contract` exports.
