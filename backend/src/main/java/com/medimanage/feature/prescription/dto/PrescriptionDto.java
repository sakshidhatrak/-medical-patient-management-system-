package com.medimanage.feature.prescription.dto;

import com.medimanage.feature.prescription.Prescription;

import java.time.Instant;

public record PrescriptionDto(
        Long id, Long visitId, Long patientId,
        String text, String drugs,
        Instant createdAt, Instant updatedAt
) {
    public static PrescriptionDto from(Prescription p) {
        return new PrescriptionDto(
                p.getId(),
                p.getVisit() != null ? p.getVisit().getId() : null,
                p.getPatient().getId(),
                p.getText(), p.getDrugs(),
                p.getCreatedAt(), p.getUpdatedAt()
        );
    }
}
