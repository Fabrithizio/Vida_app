import 'package:vida_app/data/models/timeline_block.dart';

abstract class TimelineRepository {
  Future<List<TimelineBlock>> loadAll();
  Future<void> saveAll(List<TimelineBlock> items);
}
