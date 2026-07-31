import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/gym_claim.dart';
import '../models/admin_gym_claim.dart';

abstract class GymClaimRepository {
  Future<GymClaim> submit(String gymId, {required String relationship, required String contact, required String message});
  Future<GymClaim?> myClaimForGym(String gymId);
  Future<void> withdraw(String gymId);
  Future<List<AdminGymClaim>> adminList({String status = 'pending'});
  Future<void> approve(String claimId);
  Future<void> reject(String claimId, {String? note});
}

class ApiGymClaimRepository implements GymClaimRepository {
  final Dio _dio;
  ApiGymClaimRepository(this._dio);

  @override
  Future<GymClaim> submit(String gymId, {required String relationship, required String contact, required String message}) async {
    try {
      final res = await _dio.post(Endpoints.gymClaims(gymId), data: {
        'relationship': relationship,
        'contact': contact,
        'message': message,
      });
      return GymClaim.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<GymClaim?> myClaimForGym(String gymId) async {
    try {
      final res = await _dio.get(Endpoints.gymClaimMine(gymId));
      final body = res.data as Map<String, dynamic>;
      final data = body['data'];
      if (data == null) return null;
      return GymClaim.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> withdraw(String gymId) async {
    try {
      await _dio.delete(Endpoints.gymClaimMine(gymId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<AdminGymClaim>> adminList({String status = 'pending'}) async {
    try {
      final res = await _dio.get(Endpoints.adminGymClaims, queryParameters: {'status': status});
      return unwrapList(res.data as Map<String, dynamic>).items.map(AdminGymClaim.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> approve(String claimId) async {
    try {
      await _dio.post(Endpoints.adminGymClaimApprove(claimId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> reject(String claimId, {String? note}) async {
    try {
      await _dio.post(Endpoints.adminGymClaimReject(claimId), data: {if (note != null) 'note': note});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final gymClaimRepositoryProvider = Provider<GymClaimRepository>((ref) {
  return ApiGymClaimRepository(ref.read(apiClientProvider).dio);
});

final myGymClaimProvider = FutureProvider.family<GymClaim?, String>((ref, gymId) {
  return ref.read(gymClaimRepositoryProvider).myClaimForGym(gymId);
});

final adminGymClaimsProvider = FutureProvider.family<List<AdminGymClaim>, String>((ref, status) {
  return ref.read(gymClaimRepositoryProvider).adminList(status: status);
});
