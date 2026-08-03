package com.medimanage.feature.examination.dto;

import com.medimanage.feature.examination.Examination;

import java.time.Instant;

public record ExaminationDto(
        Long id, Long visitId, Long patientId,
        String generalText, String motorText, String sensoryText,
        String reflexesText, String cerebellarText, String specialTestsText,
        String motorData, String sensoryData, String reflexData,
        Instant createdAt, Instant updatedAt
) {
    public static ExaminationDto from(Examination e) {
        return new ExaminationDto(
                e.getId(), e.getVisit().getId(), e.getPatient().getId(),
                e.getGeneralText(), e.getMotorText(), e.getSensoryText(),
                e.getReflexesText(), e.getCerebellarText(), e.getSpecialTestsText(),
                e.getMotorData(), e.getSensoryData(), e.getReflexData(),
                e.getCreatedAt(), e.getUpdatedAt()
        );
    }
}
