import '../models/models.dart';

class DataService {
  final List<Centre> centres = [
    const Centre(
      id: 'A',
      name: 'Centre A',
      address: 'Main Procurement Yard',
      lat: 28.61,
      lng: 77.10,
      capacity: 100,
      currentLoad: 0,
      processingRate: 0,
      queue: 0,
      activeStaff: 4,
      weighbridgesWorking: 1,
      weighbridgesTotal: 2,
      status: CentreStatus.normal,
      qualityTestingOk: true,
      storageOk: true,
      transportOk: true,
    ),
    const Centre(
      id: 'B',
      name: 'Centre B',
      address: 'North Village Procurement Yard',
      lat: 28.64,
      lng: 77.13,
      capacity: 100,
      currentLoad: 0,
      processingRate: 12,
      queue: 0,
      activeStaff: 6,
      weighbridgesWorking: 2,
      weighbridgesTotal: 2,
      status: CentreStatus.normal,
      qualityTestingOk: true,
      storageOk: true,
      transportOk: true,
    ),
    const Centre(
      id: 'C',
      name: 'Centre C',
      address: 'Canal Road Procurement Yard',
      lat: 28.58,
      lng: 77.16,
      capacity: 100,
      currentLoad: 0,
      processingRate: 10,
      queue: 0,
      activeStaff: 5,
      weighbridgesWorking: 2,
      weighbridgesTotal: 2,
      status: CentreStatus.normal,
      qualityTestingOk: true,
      storageOk: true,
      transportOk: true,
    ),
    const Centre(
      id: 'D',
      name: 'Centre D',
      address: 'East Block Procurement Yard',
      lat: 28.62,
      lng: 77.20,
      capacity: 100,
      currentLoad: 0,
      processingRate: 11,
      queue: 0,
      activeStaff: 5,
      weighbridgesWorking: 2,
      weighbridgesTotal: 2,
      status: CentreStatus.normal,
      qualityTestingOk: true,
      storageOk: true,
      transportOk: true,
    ),
  ];

  // The demo starts with only the 12 permanent farmer records used by the
  // application. Their true workflow state now comes from Supabase.
  final List<Farmer> farmers = List.generate(12, (i) {
    const names = [
      'Raj Kumar', 'Suresh Yadav', 'Sunita Devi', 'Mohan Singh',
      'Geeta Sharma', 'Ramesh Verma', 'Kavita Rani', 'Anil Chauhan',
      'Pooja Kumari', 'Mahender Pal', 'Rekha Devi', 'Vijay Kumar',
    ];
    const mobiles = [
      '98XXXX1001', '98XXXX1002', '98XXXX1003', '98XXXX1004',
      '98XXXX1005', '98XXXX1006', '98XXXX1007', '98XXXX1008',
      '98XXXX1009', '98XXXX1010', '98XXXX1011', '98XXXX1012',
    ];
    const villages = ['Najafgarh', 'Dhansa', 'Kair', 'Roshanpura'];
    const crops = ['Wheat', 'Paddy', 'Mustard'];
    return Farmer(
      id: 'F${(i + 1).toString().padLeft(3, '0')}',
      name: names[i],
      mobile: mobiles[i],
      village: villages[i % villages.length],
      crop: crops[i % crops.length],
      expectedQuantity: 25 + (i % 7) * 5,
      cultivatedArea: 1.2 + (i % 5) * 0.4,
      priorityScore: 55 + (i * 7) % 45,
      procurementDay: 'Not assigned',
      window: 'Not assigned',
      // The UI has always expected a Centre object to exist. The appointment
      // flag decides whether the centre is actually assigned to the farmer.
      centreId: 'A',
      state: FarmerState.assigned,
      hasLeftHome: false,
      lat: 28.57 + (i % 10) * 0.008,
      lng: 77.08 + (i % 8) * 0.012,
    );
  });

  List<VerificationItem> verification = List.filled(
    5,
    const VerificationItem('Identity', VerificationState.pending, 'Pending'),
  );

  void setVerified() {
    verification = const [
      VerificationItem('Identity', VerificationState.verified, 'Identity verified'),
      VerificationItem('Land record', VerificationState.verified, 'Land record matched'),
      VerificationItem('Bank account', VerificationState.verified, 'Bank verification matched'),
      VerificationItem('Crop', VerificationState.verified, 'Crop details verified'),
      VerificationItem('Eligibility', VerificationState.verified, 'Eligible for procurement'),
    ];
  }
}
