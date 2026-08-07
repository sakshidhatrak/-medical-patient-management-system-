import 'package:equatable/equatable.dart';

enum VisitType { opd, emergency, followUp }

extension VisitTypeX on VisitType {
  String get label => switch (this) {
        VisitType.opd      => 'OPD',
        VisitType.emergency => 'Emergency',
        VisitType.followUp  => 'Follow-up',
      };
  String get value => switch (this) {
        VisitType.opd      => 'opd',
        VisitType.emergency => 'emergency',
        VisitType.followUp  => 'follow_up',
      };
  static VisitType fromValue(String v) => switch (v) {
        'emergency' => VisitType.emergency,
        'follow_up' => VisitType.followUp,
        _           => VisitType.opd,
      };
}

class VisitEntity extends Equatable {
  final String id;
  final String patientId;
  final DateTime visitDate;
  final VisitType visitType;

  // Free-text sections
  final String? complaints;
  final String? examination;
  final String? clinicalImpression;
  final String? plan;
  final String? notes;

  final String status;   // draft / completed
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String syncStatus; // 'synced' | 'pending'

  const VisitEntity({
    required this.id,
    required this.patientId,
    required this.visitDate,
    this.visitType = VisitType.opd,
    this.complaints,
    this.examination,
    this.clinicalImpression,
    this.plan,
    this.notes,
    this.status = 'draft',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.syncStatus = 'synced',
  });

  bool get isDraft => status == 'draft';

  String get summary =>
      complaints?.isNotEmpty == true
          ? complaints!
          : clinicalImpression?.isNotEmpty == true
              ? clinicalImpression!
              : 'OPD Visit';

  VisitEntity copyWith({
    DateTime? visitDate,
    VisitType? visitType,
    String? complaints,
    String? examination,
    String? clinicalImpression,
    String? plan,
    String? notes,
    String? status,
    bool? isActive,
    String? syncStatus,
  }) =>
      VisitEntity(
        id: id,
        patientId: patientId,
        visitDate: visitDate ?? this.visitDate,
        visitType: visitType ?? this.visitType,
        complaints: complaints ?? this.complaints,
        examination: examination ?? this.examination,
        clinicalImpression: clinicalImpression ?? this.clinicalImpression,
        plan: plan ?? this.plan,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy,
        updatedBy: updatedBy,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  @override
  List<Object?> get props =>
      [id, patientId, visitDate, visitType, complaints, status];
}
