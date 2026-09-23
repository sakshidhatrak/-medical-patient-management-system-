package com.medimanage.feature.vitals.dto;

import java.time.Instant;

public record VitalsRequest(
        Long visitId,
        Instant recordedAt,
        String bp,
        String pulse,
        String temperature,
        String spo2,
        String weight,
        String height,
        String rbs
) {}
