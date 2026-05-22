import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_service.dart';
import '../shared/widgets/om_widgets.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/onboarding/screens/login_screen.dart';
import '../features/onboarding/screens/role_select_screen.dart';
import '../features/onboarding/screens/profile_setup_screen.dart';
import '../features/discover/screens/discover_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/training/screens/my_training_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/open_mats/screens/open_mat_detail_screen.dart';
import '../features/gyms/screens/gym_detail_screen.dart';
import '../features/checkins/screens/checkin_success_screen.dart';
import '../features/checkins/screens/review_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/public_profile_screen.dart';
import '../features/favorites/screens/favorites_screen.dart';
import '../features/admin/screens/owner_dashboard_screen.dart';
import '../features/admin/screens/my_gyms_screen.dart';
import '../features/admin/screens/gym_admin_screen.dart';
import '../features/admin/screens/add_gym_screen.dart';
import '../features/admin/screens/session_mgmt_screen.dart';
import '../features/admin/screens/session_admin_screen.dart';
import '../features/admin/screens/create_session_screen.dart';
import '../features/admin/screens/attendance_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Auth guard disabled for testing — remove this comment and uncomment below for production
      return null;
      // final isAuth = authState.status == AuthStatus.authenticated;
      // final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';
      final isRoleSelect = state.matchedLocation == '/role-select';
      final isProfileSetup = state.matchedLocation == '/profile-setup';

      // if (isSplash) return null;
      // if (!isAuth && !isLoggingIn) return '/login';
      // if (isAuth && isLoggingIn) return '/';
      // return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/role-select',
        builder: (context, state) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Practitioner shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ScaffoldWithNavBar(shell: shell, isOwner: false),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DiscoverScreen(),
              routes: [
                GoRoute(
                  path: 'gym/:id',
                  builder: (context, state) => GymDetailScreen(gymId: state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'open-mat/:id',
                  builder: (context, state) => OpenMatDetailScreen(openMatId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'checkin-success',
                      builder: (context, state) => CheckinSuccessScreen(openMatId: state.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'review',
                      builder: (context, state) => ReviewScreen(checkinId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/training',
              builder: (context, state) => const MyTrainingScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const EditProfileScreen(),
                ),
                GoRoute(
                  path: 'favorites',
                  builder: (context, state) => const FavoritesScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/user/:id',
              builder: (context, state) => PublicProfileScreen(userId: state.pathParameters['id']!),
            ),
          ]),
        ],
      ),

      // Gym owner shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ScaffoldWithNavBar(shell: shell, isOwner: true),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/owner/dashboard',
              builder: (context, state) => const OwnerDashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/owner/gyms',
              builder: (context, state) => const MyGymsScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  builder: (context, state) => const AddGymScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => GymAdminScreen(gymId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/owner/sessions',
              builder: (context, state) => const SessionMgmtScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const CreateSessionScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => SessionAdminScreen(sessionId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'attendance',
                      builder: (context, state) => AttendanceScreen(sessionId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/owner/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),

      // Settings (shared)
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});

class _ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell shell;
  final bool isOwner;

  const _ScaffoldWithNavBar({required this.shell, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: OMBottomNav(
        selectedIndex: shell.currentIndex,
        isOwner: isOwner,
        onTap: (index) => shell.goBranch(index),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String name;
  const _PlaceholderScreen({required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(child: Text('$name — placeholder')),
    );
  }
}
