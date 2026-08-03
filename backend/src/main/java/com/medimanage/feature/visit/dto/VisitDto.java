package com.medimanage.feature.visit.dto;

import com.medimanage.feature.visit.Visit;

import java.time.Instant;

public record VisitDto(
        Long id, Long patientId,
        Instant visitDate, String visitType,
        String complaints, String notes,
        String bp, String pulse, String temperature, String spo2, String weight, String height,
        String examPhysical, String examSystemic, String examRadiology,
        String clinicalImpression, String plan,
        String doctorAssigned, String medications, String examination,
        String status,
        Instant createdAt, Instant updatedAt
) {
    public static VisitDto from(Visit v) {
        return new VisitDto(
                v.getId(), v.getPatient().getId(),
                v.getVisitDate(), v.getVisitType(),
                v.getComplaints(), v.getNotes(),
                v.getBp(), v.getPulse(), v.getTemperature(), v.getSpo2(), v.getWeight(), v.getHeight(),
                v.getExamPhysical(), v.getExamSystemic(), v.getExamRadiology(),
                v.getClinicalImpression(), v.getPlan(),
                v.getDoctorAssigned(), v.getMedications(), v.getExamination(),
                v.getStatus(),
                v.getCreatedAt(), v.getUpdatedAt()
        );
    }
}
