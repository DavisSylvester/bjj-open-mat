import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_service.dart';
import '../shared/widgets/app_bottom_nav.dart';
import '../shared/widgets/om_widgets.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/onboarding/screens/login_screen.dart';
import '../features/onboarding/screens/role_select_screen.dart';
import '../features/onboarding/screens/profile_setup_screen.dart';
import '../features/discover/screens/discover_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/training/screens/my_training_screen.dart';
import '../features/report/screens/report_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/open_mats/screens/open_mat_detail_screen.dart';
import '../features/gyms/screens/gym_detail_screen.dart';
import '../features/checkins/screens/checkin_success_screen.dart';
import '../features/checkins/screens/check_in_form_screen.dart';
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
import '../features/admin/screens/admin_review_screen.dart';
import '../features/membership/screens/roster_screen.dart';
import '../features/membership/screens/my_memberships_screen.dart';
import '../features/classes/screens/class_schedule_screen.dart';
import '../features/classes/screens/class_occurrence_screen.dart';
import '../features/classes/screens/class_edit_screen.dart';
import '../features/classes/models/gym_class.dart';
import '../features/classes/models/scheduled_class.dart';
import '../features/classes/screens/instructor_feedback_screen.dart';
import '../features/forum/screens/forum_list_screen.dart';
import '../features/forum/screens/ask_question_screen.dart';
import '../features/forum/screens/forum_question_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;
      const authRoutes = {'/login', '/role-select', '/profile-setup', '/splash'};
      final loggingIn = authRoutes.contains(loc);

      if (auth.status == AuthStatus.initial || auth.status == AuthStatus.loading) {
        return loc == '/splash' ? null : '/splash';
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return loggingIn ? null : '/login';
      }
      // authenticated
      final user = auth.user;
      if (user != null && (user.role == null || user.role!.isEmpty)) {
        return loc == '/role-select' ? null : '/role-select';
      }
      final isOwner = user?.isGymOwner ?? false;
      if (!isOwner && loc.startsWith('/owner')) return '/';
      if (loc == '/admin/review' && user?.role != 'admin') return '/';
      if (loggingIn) return isOwner ? '/owner/dashboard' : '/';
      return null;
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
                  routes: [
                    GoRoute(
                      path: 'roster',
                      builder: (context, state) => RosterScreen(gymId: state.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'schedule',
                      builder: (context, state) => ClassScheduleScreen(gymId: state.pathParameters['id']!),
                      routes: [
                        GoRoute(
                          path: 'occurrence',
                          builder: (context, state) => ClassOccurrenceScreen(
                            classId: state.uri.queryParameters['classId'] ?? '',
                            date: state.uri.queryParameters['date'] ?? '',
                            scheduled: state.extra as ScheduledClass?,
                            gymId: state.pathParameters['id'] ?? '',
                          ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'class-edit',
                      builder: (context, state) => ClassEditScreen(
                        gymId: state.pathParameters['id']!,
                        existing: state.extra as GymClass?,
                      ),
                    ),
                    GoRoute(
                      path: 'instructor-feedback',
                      builder: (context, state) => InstructorFeedbackScreen(
                        gymId: state.pathParameters['id']!,
                      ),
                    ),
                    GoRoute(
                      path: 'forum',
                      builder: (context, state) => ForumListScreen(gymId: state.pathParameters['id']!),
                      routes: [
                        GoRoute(
                          path: 'ask',
                          builder: (context, state) => AskQuestionScreen(gymId: state.pathParameters['id']!),
                        ),
                        GoRoute(
                          path: ':questionId',
                          builder: (context, state) => ForumQuestionScreen(
                            questionId: state.pathParameters['questionId']!,
                            gymId: state.pathParameters['id']!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'open-mat/:id',
                  builder: (context, state) => OpenMatDetailScreen(sessionId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'checkin',
                      builder: (context, state) => CheckInFormScreen(openMatId: state.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'checkin-success',
                      builder: (context, state) => CheckinSuccessScreen(
                        openMatId: state.pathParameters['id']!,
                        locationStatus: state.uri.queryParameters['loc'],
                      ),
                    ),
                    GoRoute(
                      path: 'review',
                      builder: (context, state) => ReviewScreen(sessionId: state.pathParameters['id']!),
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
                GoRoute(
                  path: 'training',
                  builder: (context, state) => const MyTrainingScreen(),
                ),
                GoRoute(
                  path: 'memberships',
                  builder: (context, state) => const MyMembershipsScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/user/:id',
              builder: (context, state) => PublicProfileScreen(userId: state.pathParameters['id']!),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/report',
              builder: (context, state) => const ReportScreen(),
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
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/owner/report',
              builder: (context, state) => const ReportScreen(),
            ),
          ]),
        ],
      ),

      // Add session (shared — any authenticated role)
      GoRoute(
        path: '/add-session',
        builder: (context, state) => const CreateSessionScreen(),
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

      // Admin
      GoRoute(
        path: '/admin/review',
        builder: (context, state) => const AdminReviewScreen(),
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
      body: shell,
      bottomNavigationBar: isOwner
          ? OMBottomNav(
              selectedIndex: shell.currentIndex,
              isOwner: true,
              onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
              onAdd: () => context.push('/add-session'),
            )
          : AppBottomNav(
              active: kPracTabs[shell.currentIndex],
              onTap: (tabId) {
                final idx = kPracTabs.indexOf(tabId);
                shell.goBranch(idx, initialLocation: idx == shell.currentIndex);
              },
              onAdd: () => context.push('/add-session'),
            ),
    );
  }
}
