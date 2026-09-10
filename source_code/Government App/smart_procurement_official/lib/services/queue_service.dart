
import '../models/models.dart';
class QueueService {
  int ahead(Centre c) => c.queue > 0 ? (c.queue ~/ 3).clamp(0, c.queue) : 0;
  int waitMinutes(Centre c) => c.processingRate <= 0 ? 0 : ((ahead(c)/c.processingRate)*60).round();
}
