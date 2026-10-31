import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopdesk/core/widgets/app_card.dart';
import 'package:shopdesk/core/widgets/empty_state.dart';
import 'package:shopdesk/features/predictor/application/predictor_providers.dart';
import 'package:shopdesk/features/predictor/domain/forecast_service.dart';
import 'package:shopdesk/features/products/presentation/widgets/product_avatar.dart';

class PredictorPage extends ConsumerWidget {
  const PredictorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(forecastDaysProvider);
    final forecast = ref.watch(forecastProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Predictor')),
      body: forecast.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not build the forecast: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              message: 'Add products and make some sales. Forecasts appear here.',
              icon: Icons.insights_outlined,
            );
          }
          final maxSold = rows.fold(1, (m, r) => r.sold > m ? r.sold : m);
          final best = rows.take(5).toList();
          final worst = rows.reversed.take(5).toList();

          Widget rankCard(String title, List<ProductForecast> list) => AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    for (final r in list)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            ProductAvatar(product: r.product, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(value: r.sold / maxSold, minHeight: 6),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('${r.sold} sold', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Uses your past sales to show what moves fast, what sits, and what to reorder.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 7, label: Text('Last 7 days')),
                  ButtonSegment(value: 30, label: Text('Last 30 days')),
                ],
                selected: {days},
                onSelectionChanged: (s) => ref.read(forecastDaysProvider.notifier).state = s.first,
              ),
              const SizedBox(height: 16),
              rankCard('Selling the most', best),
              const SizedBox(height: 12),
              rankCard('Selling the least', worst),
              const SizedBox(height: 16),
              Text('Restock forecast', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        ProductAvatar(product: r.product, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${r.sold} sold · ${r.perDay.toStringAsFixed(1)}/day · ${r.product.stock} in stock\n'
                                'Lasts ${r.daysLeft == null ? '–' : '${r.daysLeft!.round()} days'}'
                                '${_trend(r)}',
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        _AdviceChip(r),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _trend(ProductForecast r) {
    final t = r.trendPercent;
    if (t == null) return '';
    return ' · ${t >= 0 ? '▲ +' : '▼ '}$t% vs previous';
  }
}

class _AdviceChip extends StatelessWidget {
  const _AdviceChip(this.r);
  final ProductForecast r;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (r.advice) {
      ForecastAdvice.outOfStock => ('Out · reorder now', s.errorContainer, s.onErrorContainer),
      ForecastAdvice.reorder => ('Order about ${r.suggestedOrder}', s.tertiaryContainer, s.onTertiaryContainer),
      ForecastAdvice.notSelling => ('Not selling', s.tertiaryContainer, s.onTertiaryContainer),
      ForecastAdvice.ok => ('Stock is fine', s.primaryContainer, s.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
