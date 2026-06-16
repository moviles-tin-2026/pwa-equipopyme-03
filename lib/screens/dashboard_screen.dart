import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'app_theme.dart';

/// Dashboard con métricas reactivas de inventario y ventas.
///
/// **Integración con [FirestoreService]:**
/// - `watchDashboardMetrics()` → `Stream<DashboardMetrics>`
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.firestoreService,
  });

  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return PymeScaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.35),
        title: const Text('Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      padding: const EdgeInsets.all(24),
      body: StreamBuilder<DashboardMetrics>(
        stream: firestoreService.watchDashboardMetrics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: StatusBanner.loading());
          }
          if (snapshot.hasError) {
            return StatusBanner.error(
              message: 'Error al cargar métricas: ${snapshot.error}',
            );
          }

          final metrics = snapshot.data ??
              const DashboardMetrics(
                totalProducts: 0,
                totalStock: 0,
                salesToday: 0,
                salesMonth: 0,
              );

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = responsiveColumns(
                constraints.maxWidth,
                mobile: 1,
                tablet: 2,
                desktop: 4,
              );

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard', style: AppTextStyles.screenTitle),
                    const SizedBox(height: 8),
                    Text(
                      'Resumen operativo en tiempo real',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: columns == 1 ? 2.2 : 1.4,
                      children: [
                        _MetricCard(
                          title: 'Total productos',
                          value: '${metrics.totalProducts}',
                          icon: Icons.inventory_2_outlined,
                          accent: AppColors.linkBlue,
                        ),
                        _MetricCard(
                          title: 'Stock total',
                          value: '${metrics.totalStock}',
                          icon: Icons.warehouse_outlined,
                          accent: AppColors.successGreen,
                        ),
                        _MetricCard(
                          title: 'Ventas hoy',
                          value: '\$${metrics.salesToday.toStringAsFixed(2)}',
                          icon: Icons.today_outlined,
                          accent: AppColors.meshPurple,
                        ),
                        _MetricCard(
                          title: 'Ventas del mes',
                          value: '\$${metrics.salesMonth.toStringAsFixed(2)}',
                          icon: Icons.calendar_month_outlined,
                          accent: AppColors.navy,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final isWide =
                            innerConstraints.maxWidth >= AppBreakpoints.tablet;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _SalesChartCard(
                                  salesToday: metrics.salesToday,
                                  salesMonth: metrics.salesMonth,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _StockOverviewCard(
                                  totalProducts: metrics.totalProducts,
                                  totalStock: metrics.totalStock,
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _SalesChartCard(
                              salesToday: metrics.salesToday,
                              salesMonth: metrics.salesMonth,
                            ),
                            const SizedBox(height: 20),
                            _StockOverviewCard(
                              totalProducts: metrics.totalProducts,
                              totalStock: metrics.totalStock,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.successGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Activo',
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title.toUpperCase(),
            style: AppTextStyles.labelUppercase,
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.metricValue),
        ],
      ),
    );
  }
}

class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({
    required this.salesToday,
    required this.salesMonth,
  });

  final double salesToday;
  final double salesMonth;

  @override
  Widget build(BuildContext context) {
    final todayRatio =
        salesMonth > 0 ? (salesToday / salesMonth).clamp(0.0, 1.0) : 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rendimiento de ventas', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: todayRatio,
                        strokeWidth: 10,
                        backgroundColor: AppColors.tagBackground,
                        color: AppColors.linkBlue,
                      ),
                    ),
                    Text(
                      '${(todayRatio * 100).toStringAsFixed(0)}%',
                      style: AppTextStyles.metricValue.copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proporción ventas hoy / mes',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LegendRow(
                      label: 'Hoy',
                      value: '\$${salesToday.toStringAsFixed(2)}',
                      color: AppColors.linkBlue,
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      label: 'Mes',
                      value: '\$${salesMonth.toStringAsFixed(2)}',
                      color: AppColors.meshPurple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockOverviewCard extends StatelessWidget {
  const _StockOverviewCard({
    required this.totalProducts,
    required this.totalStock,
  });

  final int totalProducts;
  final int totalStock;

  @override
  Widget build(BuildContext context) {
    final avgStock =
        totalProducts > 0 ? (totalStock / totalProducts) : 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inventario', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 20),
          _ProgressRow(
            label: 'Productos activos',
            value: totalProducts,
            max: totalProducts > 0 ? totalProducts : 1,
            color: AppColors.linkBlue,
          ),
          const SizedBox(height: 16),
          _ProgressRow(
            label: 'Stock promedio',
            value: avgStock.round(),
            max: totalStock > 0 ? totalStock : 1,
            color: AppColors.successGreen,
          ),
          const SizedBox(height: 16),
          _ProgressRow(
            label: 'Unidades totales',
            value: totalStock,
            max: totalStock > 0 ? totalStock : 1,
            color: AppColors.meshPurple,
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.body),
        const Spacer(),
        Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.body),
            Text('$value', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: max > 0 ? (value / max).clamp(0.0, 1.0) : 0,
            minHeight: 8,
            backgroundColor: AppColors.tagBackground,
            color: color,
          ),
        ),
      ],
    );
  }
}
