import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../../core/data/api_exception.dart';
import '../models/conversation.dart';
import '../models/conversation_summary.dart';
import '../models/message.dart';
import '../models/message_report.dart';

abstract class MessagingRepository {
  Future<List<ConversationSummary>> listConversations({int page, int limit});
  Future<List<Message>> listMessages(
    String conversationId, {
    String? before,
    int limit,
  });
  Future<Message> sendMessage(String conversationId, String body);
  Future<Conversation> startDirect(String recipientId);
  Future<Conversation> createGroup(
    String gymId,
    String title,
    List<String> participantIds,
  );
  Future<List<Conversation>> listChannels(String gymId);
  Future<Conversation> createChannel(String gymId, String title);
  Future<void> markRead(String conversationId);
  Future<void> setMuted(String conversationId, bool muted);
  Future<void> leave(String conversationId);
  Future<void> addParticipants(String conversationId, List<String> userIds);
  Future<Message> editMessage(String messageId, String body);
  Future<void> deleteMessage(String messageId);
  Future<void> reportMessage({
    String? messageId,
    required String reportedUserId,
    required String reason,
    String? note,
  });
  Future<List<MessageReport>> listGymReports(String gymId, {String? status});
  Future<void> resolveReport(String reportId, String status);
  Future<List<String>> listBlocks();
  Future<void> blockUser(String userId);
  /// Removes the block on [blockedId] (the blocked user's id).
  Future<void> unblockUser(String blockedId);
}

class ApiMessagingRepository implements MessagingRepository {
  final Dio _dio;

  ApiMessagingRepository(this._dio);

  @override
  Future<List<ConversationSummary>> listConversations({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get(
        Endpoints.messagingConversations,
        queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(ConversationSummary.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<Message>> listMessages(
    String conversationId, {
    String? before,
    int limit = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'limit': limit,
        if (before != null) 'before': before,
      };
      final res = await _dio.get(
        Endpoints.messagingConversationMessages(conversationId),
        queryParameters: query,
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(Message.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Message> sendMessage(String conversationId, String body) async {
    try {
      final res = await _dio.post(
        Endpoints.messagingConversationMessages(conversationId),
        data: {'body': body},
      );
      return Message.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Conversation> startDirect(String recipientId) async {
    try {
      final res = await _dio.post(
        Endpoints.messagingDirect,
        data: {'recipientId': recipientId},
      );
      return Conversation.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Conversation> createGroup(
    String gymId,
    String title,
    List<String> participantIds,
  ) async {
    try {
      final res = await _dio.post(
        Endpoints.messagingGroups,
        data: {
          'gymId': gymId,
          'title': title,
          'participantIds': participantIds,
        },
      );
      return Conversation.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<Conversation>> listChannels(String gymId) async {
    try {
      final res = await _dio.get(Endpoints.gymChannels(gymId));
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(Conversation.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Conversation> createChannel(String gymId, String title) async {
    try {
      final res = await _dio.post(
        Endpoints.gymChannels(gymId),
        data: {'title': title},
      );
      return Conversation.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> markRead(String conversationId) async {
    try {
      await _dio.post(Endpoints.messagingConversationRead(conversationId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> setMuted(String conversationId, bool muted) async {
    try {
      await _dio.post(
        Endpoints.messagingConversationMute(conversationId),
        data: {'muted': muted},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> leave(String conversationId) async {
    try {
      await _dio.post(Endpoints.messagingConversationLeave(conversationId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> addParticipants(
    String conversationId,
    List<String> userIds,
  ) async {
    try {
      await _dio.post(
        Endpoints.messagingConversationParticipants(conversationId),
        data: {'userIds': userIds},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Message> editMessage(String messageId, String body) async {
    try {
      final res = await _dio.patch(
        Endpoints.messagingMessage(messageId),
        data: {'body': body},
      );
      return Message.fromJson(unwrapData(res.data as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      await _dio.delete(Endpoints.messagingMessage(messageId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> reportMessage({
    String? messageId,
    required String reportedUserId,
    required String reason,
    String? note,
  }) async {
    try {
      final data = <String, dynamic>{
        'reportedUserId': reportedUserId,
        'reason': reason,
        if (note != null) 'note': note,
      };
      final endpoint = messageId != null
          ? Endpoints.messagingMessageReport(messageId)
          : Endpoints.messagingReports;
      await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<MessageReport>> listGymReports(
    String gymId, {
    String? status,
  }) async {
    try {
      final query = <String, dynamic>{
        if (status != null) 'status': status,
      };
      final res = await _dio.get(
        Endpoints.gymMessageReports(gymId),
        queryParameters: query.isNotEmpty ? query : null,
      );
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map(MessageReport.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> resolveReport(String reportId, String status) async {
    try {
      await _dio.post(
        Endpoints.messagingReportResolve(reportId),
        data: {'status': status},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<String>> listBlocks() async {
    try {
      final res = await _dio.get(Endpoints.messagingBlocks);
      return unwrapList(res.data as Map<String, dynamic>)
          .items
          .map((item) => item['blockedId'] as String)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> blockUser(String userId) async {
    try {
      await _dio.post(Endpoints.messagingBlocks, data: {'userId': userId});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> unblockUser(String blockedId) async {
    try {
      await _dio.delete(Endpoints.messagingBlock(blockedId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return ApiMessagingRepository(ref.read(apiClientProvider).dio);
});

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>((ref) {
  return ref.read(messagingRepositoryProvider).listConversations();
});

final messagesProvider =
    FutureProvider.family.autoDispose<List<Message>, String>((ref, conversationId) {
  return ref.read(messagingRepositoryProvider).listMessages(conversationId);
});

final gymChannelsProvider =
    FutureProvider.family<List<Conversation>, String>((ref, gymId) {
  return ref.read(messagingRepositoryProvider).listChannels(gymId);
});

final blocksProvider = FutureProvider<List<String>>((ref) {
  return ref.read(messagingRepositoryProvider).listBlocks();
});

final gymMessageReportsProvider = FutureProvider.family<List<MessageReport>,
    ({String gymId, String? status})>((ref, args) {
  return ref
      .read(messagingRepositoryProvider)
      .listGymReports(args.gymId, status: args.status);
});
