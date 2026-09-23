package com.medimanage.feature.vitals.dto;

import com.medimanage.feature.vitals.Vitals;

import java.time.Instant;

public record VitalsDto(
        Long id,
        Long patientId,
        Long visitId,
        Instant recordedAt,
        String bp,
        String pulse,
        String temperature,
        String spo2,
        String weight,
        String height,
        String rbs,
        Instant createdAt,
        Instant updatedAt
) {
    public static VitalsDto from(Vitals v) {
        return new VitalsDto(
                v.getId(),
                v.getPatient().getId(),
                v.getVisitId(),
                v.getRecordedAt(),
                v.getBp(), v.getPulse(), v.getTemperature(),
                v.getSpo2(), v.getWeight(), v.getHeight(), v.getRbs(),
                v.getCreatedAt(), v.getUpdatedAt()
        );
    }
}
