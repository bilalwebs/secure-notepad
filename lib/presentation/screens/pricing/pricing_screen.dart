import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _isYearly = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Choose Your Plan',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Header ──
            Text(
              'Unlock Premium Features',
              style: GoogleFonts.sora(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.textLight : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get the most out of Secure Notepad',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // ── Monthly/Yearly Toggle ──
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isYearly = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isYearly
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Monthly',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              color: !_isYearly
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isYearly = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isYearly
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Yearly',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              color: _isYearly
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Pricing Cards ──
            Row(
              children: [
                Expanded(
                  child: _buildPricingCard(
                    title: 'Plus',
                    price: _isYearly ? '\$44' : '\$55',
                    period: _isYearly ? '/mo (billed yearly)' : '/month',
                    features: [
                      'Unlimited notes',
                      'Basic encryption',
                      'Voice notes',
                      'Cloud sync',
                      'Email support',
                    ],
                    isPopular: false,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPricingCard(
                    title: 'Pro',
                    price: _isYearly ? '\$64' : '\$80',
                    period: _isYearly ? '/mo (billed yearly)' : '/month',
                    features: [
                      'Everything in Plus',
                      'AI-powered features',
                      'Advanced encryption',
                      'Priority support',
                      'Custom themes',
                      'Export to PDF',
                    ],
                    isPopular: true,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Continue Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'In-app purchase coming soon!'),
                    ),
                  );
                },
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cancel anytime. No hidden fees.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required bool isPopular,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular
              ? AppTheme.primary
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'POPULAR',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          if (isPopular) const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.sora(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  period,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
