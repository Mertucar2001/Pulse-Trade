import 'package:flutter/material.dart';

import '../models/market_models.dart';
import '../theme/app_colors.dart';

class FinanceBackground extends StatelessWidget {
  const FinanceBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FinancePainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF020816), Color(0xFF07182D), Color(0xFF020816)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class FinancePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 58) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 58) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    canvas.drawCircle(
      Offset(size.width * .16, size.height * .30),
      290,
      Paint()
        ..color = AppColors.blue.withValues(alpha: .18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LogoBox extends StatelessWidget {
  final double size;
  const LogoBox({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8DFF83), Color(0xFF19C95F)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: .28),
            blurRadius: 24,
          ),
        ],
      ),
      child: Icon(Icons.monitor_heart, color: Colors.black, size: size * .50),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .34),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PageShell extends StatelessWidget {
  final String title;
  final Widget child;

  const PageShell({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF07101D),
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: FinanceBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class StockTile extends StatelessWidget {
  final StockQuote stock;
  final String Function(double) formatPrice;
  final VoidCallback? onTap;

  const StockTile({
    super.key,
    required this.stock,
    required this.formatPrice,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = stock.isUp ? AppColors.green : AppColors.red;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .18),
              child: Text(
                stock.logo,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(stock.symbol, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            SizedBox(width: 80, height: 34, child: MiniLine(color: color)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(stock.price), style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(stock.formattedChange, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MiniLine extends StatelessWidget {
  final Color color;
  const MiniLine({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: MiniLinePainter(color));
  }
}

class MiniLinePainter extends CustomPainter {
  final Color color;
  MiniLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [0.72, 0.58, 0.63, 0.46, 0.52, 0.38, 0.43, 0.25];
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = size.width * i / (pts.length - 1);
      final y = size.height * pts[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant MiniLinePainter oldDelegate) => oldDelegate.color != color;
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.green),
    );
  }
}

class CountryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CountryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.green.withValues(alpha: .18) : Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.green : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.green : AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
