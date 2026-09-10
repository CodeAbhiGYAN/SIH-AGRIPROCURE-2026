import 'package:flutter/material.dart';
import '../services/msp_service.dart';
import '../main.dart';
import '../widgets/common.dart';

class MspScreen extends StatelessWidget {
  final AppState state;
  const MspScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final service = MspService();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(state.t('msp_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(state.t('msp_sub')),
        const SizedBox(height: 14),
        ...service.entries.map(
          (e) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(e.crop, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    Text(e.season, style: TextStyle(color: Colors.grey.shade700)),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${e.current}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      Text(e.unit),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${e.change >= 0 ? '+' : ''}₹${e.change} • ${e.percentChange.toStringAsFixed(1)}% vs previous year',
                    style: TextStyle(fontWeight: FontWeight.w700, color: e.change >= 0 ? Colors.green.shade700 : Colors.red.shade700),
                  ),
                  const SizedBox(height: 6),
                  Text('Source: ${e.source} • Updated ${e.lastUpdated}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        InfoCard(title: state.t('automatic_updates'), icon: Icons.sync, child: Text(state.t('msp_auto'))),
      ],
    );
  }
}
