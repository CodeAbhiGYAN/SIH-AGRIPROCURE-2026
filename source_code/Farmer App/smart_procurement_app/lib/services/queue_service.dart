import 'procurement_timing.dart';

class QueueService {
  int waitMinutesFromAhead(int farmersAhead) =>
      ProcurementTiming.waitFromFarmersAhead(farmersAhead);
}
