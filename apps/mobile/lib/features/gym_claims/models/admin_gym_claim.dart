import 'gym_claim.dart';

class AdminGymClaim {
  final GymClaim claim;
  final String gymName;
  final String? gymPhone;
  final String? gymWebsite;
  final String? claimantEmail;

  const AdminGymClaim({
    required this.claim,
    required this.gymName,
    this.gymPhone,
    this.gymWebsite,
    this.claimantEmail,
  });

  factory AdminGymClaim.fromJson(Map<String, dynamic> json) => AdminGymClaim(
        claim: GymClaim.fromJson(json['claim'] as Map<String, dynamic>),
        gymName: json['gymName'] as String? ?? 'Gym',
        gymPhone: json['gymPhone'] as String?,
        gymWebsite: json['gymWebsite'] as String?,
        claimantEmail: json['claimantEmail'] as String?,
      );
}
