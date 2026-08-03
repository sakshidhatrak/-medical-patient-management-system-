package com.medimanage.feature.surgery.dto;

import com.medimanage.feature.surgery.Surgery;

import java.time.Instant;

public record SurgeryDto(
        Long id, Long patientId, Instant surgeryDate,
        String yourRole, String preOpDiagnosis, String procedure,
        String primarySurgeon, String assistantSurgeons,
        String anesthesiaType, String anesthesiologist,
        String implants, String implantDetails,
        String intraopFindings, String otNotes, String complications,
        String postOpPlan, String status,
        Instant createdAt, Instant updatedAt
) {
    public static SurgeryDto from(Surgery s) {
        return new SurgeryDto(
                s.getId(), s.getPatient().getId(), s.getSurgeryDate(),
                s.getYourRole(), s.getPreOpDiagnosis(), s.getProcedure(),
                s.getPrimarySurgeon(), s.getAssistantSurgeons(),
                s.getAnesthesiaType(), s.getAnesthesiologist(),
                s.getImplants(), s.getImplantDetails(),
                s.getIntraopFindings(), s.getOtNotes(), s.getComplications(),
                s.getPostOpPlan(), s.getStatus(),
                s.getCreatedAt(), s.getUpdatedAt()
        );
    }
}
