package com.medimanage.feature.radiology.dto;

import com.medimanage.feature.radiology.Radiology;

import java.time.Instant;

public record RadiologyDto(
        Long id, Long patientId, Long visitId, Long surgeryId,
        String text, String investigations,
        Instant createdAt, Instant updatedAt
) {
    public static RadiologyDto from(Radiology r) {
        return new RadiologyDto(
                r.getId(), r.getPatient().getId(), r.getVisitId(), r.getSurgeryId(),
                r.getText(), r.getInvestigations(),
                r.getCreatedAt(), r.getUpdatedAt()
        );
    }
}
