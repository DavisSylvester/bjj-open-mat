import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/data/api_envelope.dart';
import '../../checkins/models/checkin.dart';

class TrainingHistory {
  final List<CheckIn> items;
  final int total;
  const TrainingHistory({required this.items, required this.total});
}

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatSessionDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_monthNames[d.month - 1]} ${d.day}';
}

final myTrainingProvider = FutureProvider<TrainingHistory>((ref) async {
  final dio = ref.read(apiClientProvider).dio;
  final res = await dio.get(Endpoints.myCheckins, queryParameters: {'page': 1, 'limit': 100});
  final result = unwrapList(res.data as Map<String, dynamic>);
  final items = result.items.map(CheckIn.fromJson).toList()
    ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
  return TrainingHistory(items: items, total: result.total);
});
