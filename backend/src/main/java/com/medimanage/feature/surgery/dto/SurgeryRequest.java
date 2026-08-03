package com.medimanage.feature.surgery.dto;

import java.time.Instant;

public record SurgeryRequest(
        Instant surgeryDate,
        String yourRole,
        String preOpDiagnosis,
        String procedure,
        String primarySurgeon,
        String assistantSurgeons,
        String anesthesiaType,
        String anesthesiologist,
        String implants,
        String implantDetails,
        String intraopFindings,
        String otNotes,
        String complications,
        String postOpPlan,
        String status
) {}
