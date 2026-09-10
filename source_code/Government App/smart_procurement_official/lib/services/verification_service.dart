
import '../models/models.dart';
class VerificationService {
  List<VerificationItem> getMockVerification() => const [
    VerificationItem('Identity', VerificationState.verified, 'Mock e-KYC confirmed'),
    VerificationItem('Land', VerificationState.verified, 'Mock land record matched'),
    VerificationItem('Bank account', VerificationState.verified, 'Mock bank verification matched'),
    VerificationItem('Crop / eligibility', VerificationState.verified, 'Season and crop eligible'),
    VerificationItem('Supporting documents', VerificationState.verified, 'No action required'),
  ];
}
