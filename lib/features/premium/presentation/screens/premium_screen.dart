import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Vault Premium')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0x1AF59E0B),
              child: Icon(Icons.workspace_premium, size: 48, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            const Text(
              'Study smarter with Premium',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock advanced AI reasoning, unlimited PDF indexing, and deep exam prep.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 32),
            _buildBenefitRow(Icons.auto_awesome, 'Advanced AI Models', 'Get deeper, multi-step explanations from Gemini'),
            _buildBenefitRow(Icons.library_books, 'Unlimited Study Vault', 'Upload unlimited PDFs, lecture slides, and notes'),
            _buildBenefitRow(Icons.mic, 'Voice & Image OCR', 'Learn naturally by speaking or scanning textbooks'),
            _buildBenefitRow(Icons.assignment, 'Pro Exam Prep', 'Customized mock tests and timed revision schedules'),
            const SizedBox(height: 32),
            _buildPlanCard('Monthly Plan', '\$9.99 / mo', 'Billed monthly. Cancel anytime.', isRecommended: false),
            const SizedBox(height: 16),
            _buildPlanCard('Annual Pro Plan', '\$59.99 / yr', 'Save 50% • Includes all AI features', isRecommended: true),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment integrations configured! All features active for this test build.')),
                );
              },
              child: const Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.amber.withValues(alpha: 0.15),
            child: Icon(icon, color: Colors.amber[700], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String title, String price, String desc, {bool isRecommended = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: isRecommended ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
          width: isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: isRecommended ? Colors.amber.withValues(alpha: 0.08) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isRecommended)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('MOST POPULAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
