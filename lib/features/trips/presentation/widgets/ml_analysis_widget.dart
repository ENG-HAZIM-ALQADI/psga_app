import 'package:flutter/material.dart';
import 'package:psga_app/core/services/ml_analysis_service.dart';

/// بطاقة عرض التحليل الذكي بالـ ML
class MLAnalysisCard extends StatelessWidget {
  final ComprehensiveAnalysisResult analysis;
  final VoidCallback? onActionPressed;
  
  const MLAnalysisCard({
    required this.analysis,
    super.key,
    this.onActionPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getColorForRisk(analysis.alertLevel).withOpacity(0.1),
              _getColorForRisk(analysis.alertLevel).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getColorForRisk(analysis.alertLevel),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconForRisk(analysis.alertLevel),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🤖 التحليل الذكي',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'تحليل بالذكاء الاصطناعي',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // مؤشر درجة الخطر
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'مستوى الخطر الإجمالي',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${analysis.overallRiskScore.toStringAsFixed(0)}/100',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getColorForRisk(analysis.alertLevel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: analysis.overallRiskScore / 100,
                      minHeight: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        _getColorForRisk(analysis.alertLevel),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // الرسالة
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getColorForRisk(analysis.alertLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getColorForRisk(analysis.alertLevel).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: _getColorForRisk(analysis.alertLevel),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        analysis.alertMessage,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getColorForRisk(analysis.alertLevel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // تفاصيل تحليل المسار
              if (analysis.routeAnalysis.analysis.anomalyCount > 0) ...[
                const SizedBox(height: 16),
                _buildDetailSection(
                  icon: Icons.route,
                  title: 'تحليل المسار',
                  details: [
                    'نقاط شاذة: ${analysis.routeAnalysis.analysis.anomalyCount}/${analysis.routeAnalysis.analysis.totalPoints}',
                    'متوسط الانحراف: ${analysis.routeAnalysis.analysis.avgDeviationMeters.toStringAsFixed(1)} متر',
                  ],
                ),
              ],
              
              // تفاصيل تحليل الأنماط
              if (analysis.patternAnalysis.currentAnalysis.isUnusual) ...[
                const SizedBox(height: 16),
                _buildDetailSection(
                  icon: Icons.psychology,
                  title: 'تحليل الأنماط',
                  details: analysis.patternAnalysis.currentAnalysis.anomalies
                      .map((a) => a.message)
                      .toList(),
                ),
              ],
              
              // زر الإجراء
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onActionPressed,
                  icon: Icon(_getActionIcon(analysis.recommendedAction)),
                  label: Text(_getActionText(analysis.recommendedAction)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getColorForRisk(analysis.alertLevel),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required List<String> details,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...details.map((detail) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    detail,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Color _getColorForRisk(String level) {
    switch (level) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }
  
  IconData _getIconForRisk(String level) {
    switch (level) {
      case 'high':
        return Icons.error;
      case 'medium':
        return Icons.warning;
      case 'low':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }
  
  IconData _getActionIcon(String action) {
    switch (action) {
      case 'emergency_alert':
        return Icons.emergency;
      case 'notify_user':
        return Icons.notifications_active;
      case 'monitor':
        return Icons.visibility;
      default:
        return Icons.check;
    }
  }
  
  String _getActionText(String action) {
    switch (action) {
      case 'emergency_alert':
        return 'إجراء طوارئ فوري';
      case 'notify_user':
        return 'تنبيه جهات الاتصال';
      case 'monitor':
        return 'مراقبة دقيقة';
      default:
        return 'متابعة عادية';
    }
  }
}

/// Widget بسيط لعرض تحليل المسار فقط
class RouteAnalysisWidget extends StatelessWidget {
  final RouteAnalysis analysis;
  
  const RouteAnalysisWidget({
    required this.analysis,
    super.key,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: _getColorForRisk(analysis.riskLevel),
                ),
                const SizedBox(width: 8),
                const Text(
                  'تحليل المسار',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('النقاط الشاذة', '${analysis.anomalyCount}/${analysis.totalPoints}'),
            _buildInfoRow('متوسط الانحراف', '${analysis.avgDeviationMeters.toStringAsFixed(1)} متر'),
            _buildInfoRow('أقصى انحراف', '${analysis.maxDeviationMeters.toStringAsFixed(1)} متر'),
            _buildInfoRow('درجة الخطر', '${analysis.riskScore.toStringAsFixed(0)}/100'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getColorForRisk(analysis.riskLevel).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                analysis.recommendedAction,
                style: TextStyle(
                  color: _getColorForRisk(analysis.riskLevel),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  
  Color _getColorForRisk(String level) {
    switch (level) {
      case 'critical':
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }
}
