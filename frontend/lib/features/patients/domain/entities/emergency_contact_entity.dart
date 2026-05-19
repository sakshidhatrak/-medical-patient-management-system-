import 'package:equatable/equatable.dart';

class EmergencyContactEntity extends Equatable {
  final String? name;
  final String? phone;
  final String? relationship;
  final String? insuranceProvider;
  final String? insuranceNumber;

  const EmergencyContactEntity({
    this.name,
    this.phone,
    this.relationship,
    this.insuranceProvider,
    this.insuranceNumber,
  });

  bool get hasInsurance =>
      insuranceProvider != null || insuranceNumber != null;

  @override
  List<Object?> get props =>
      [name, phone, relationship, insuranceProvider, insuranceNumber];
}
