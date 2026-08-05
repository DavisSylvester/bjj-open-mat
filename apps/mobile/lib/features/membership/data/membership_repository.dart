import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/belt_promotion.dart';
import '../models/gym_membership.dart';
import '../models/roster_member.dart';

abstract class MembershipRepository {
  Future<GymMembership> join(String gymId);
  Future<void> leave(String gymId);
  Future<List<RosterMember>> roster(String gymId);
  Future<List<RosterMember>> manageRoster(String gymId);
  Future<GymMembership> updateMine(String gymId, {bool? visibleInRoster, bool? isHome});
  Future<GymMembership> manageMember(
    String gymId,
    String userId, {
    bool? verifiedMember,
    String? gymRole,
    String? status,
  });
  Future<BeltPromotion> promote(
    String gymId,
    String userId, {
    required String beltRank,
    required int beltStripes,
    String? note,
  });
  Future<List<BeltPromotion>> userPromotions(String userId);
  Future<List<GymMembership>> myMemberships();
}

class ApiMembershipRepository implements MembershipRepository {
  final Dio _dio;
  ApiMembershipRepository(this._dio);

  @override
  Future<GymMembership> join(String gymId) async {
    try {
      final res = await _dio.post(Endpoints.gymMembers(gymId));
      return GymMembership.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> leave(String gymId) async {
    try {
      await _dio.delete(Endpoints.gymMemberMe(gymId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<RosterMember>> roster(String gymId) async {
    try {
      final res = await _dio.get(Endpoints.gymMembers(gymId));
      return unwrapList(res.data as Map<String, dynamic>).items.map(RosterMember.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<RosterMember>> manageRoster(String gymId) async {
    try {
      final res = await _dio.get(Endpoints.gymMembersManage(gymId));
      return unwrapList(res.data as Map<String, dynamic>).items.map(RosterMember.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<GymMembership> updateMine(String gymId, {bool? visibleInRoster, bool? isHome}) async {
    try {
      final body = <String, dynamic>{
        if (visibleInRoster != null) 'visibleInRoster': visibleInRoster,
        if (isHome != null) 'isHome': isHome,
      };
      final res = await _dio.patch(Endpoints.gymMemberMe(gymId), data: body);
      return GymMembership.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<GymMembership> manageMember(
    String gymId,
    String userId, {
    bool? verifiedMember,
    String? gymRole,
    String? status,
  }) async {
    try {
      final body = <String, dynamic>{
        if (verifiedMember != null) 'verifiedMember': verifiedMember,
        if (gymRole != null) 'gymRole': gymRole,
        if (status != null) 'status': status,
      };
      final res = await _dio.patch(Endpoints.gymMember(gymId, userId), data: body);
      return GymMembership.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<BeltPromotion> promote(
    String gymId,
    String userId, {
    required String beltRank,
    required int beltStripes,
    String? note,
  }) async {
    try {
      final body = <String, dynamic>{
        'beltRank': beltRank,
        'beltStripes': beltStripes,
        if (note != null) 'note': note,
      };
      final res = await _dio.post(Endpoints.gymMemberPromotions(gymId, userId), data: body);
      return BeltPromotion.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<BeltPromotion>> userPromotions(String userId) async {
    try {
      final res = await _dio.get(Endpoints.userPromotions(userId));
      return unwrapList(res.data as Map<String, dynamic>).items.map(BeltPromotion.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<GymMembership>> myMemberships() async {
    try {
      final res = await _dio.get(Endpoints.myMemberships);
      return unwrapList(res.data as Map<String, dynamic>).items.map(GymMembership.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return ApiMembershipRepository(ref.read(apiClientProvider).dio);
});

final rosterProvider = FutureProvider.family<List<RosterMember>, String>((ref, gymId) {
  return ref.read(membershipRepositoryProvider).roster(gymId);
});

/// Manager-only roster: also carries hidden and inactive members. Deliberately
/// separate from [rosterProvider] so the DM picker, class assignment, and
/// permission derivations keep seeing only active, visible members.
final manageRosterProvider = FutureProvider.family<List<RosterMember>, String>((ref, gymId) {
  return ref.read(membershipRepositoryProvider).manageRoster(gymId);
});

final userPromotionsProvider = FutureProvider.family<List<BeltPromotion>, String>((ref, userId) {
  return ref.read(membershipRepositoryProvider).userPromotions(userId);
});

final myMembershipsProvider = FutureProvider<List<GymMembership>>((ref) {
  return ref.read(membershipRepositoryProvider).myMemberships();
});
