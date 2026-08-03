package com.medimanage.feature.visit.dto;

import java.time.Instant;

public record VisitRequest(
        Instant visitDate,
        String visitType,
        String complaints,
        String notes,
        String bp,
        String pulse,
        String temperature,
        String spo2,
        String weight,
        String height,
        String examPhysical,
        String examSystemic,
        String examRadiology,
        String clinicalImpression,
        String plan,
        String doctorAssigned,
        String medications,
        String examination,
        String status
) {}
