package com.medimanage.feature.appointment.dto;

import java.time.Instant;

public record AppointmentRequest(
        Instant scheduledAt,
        String status,
        String appointmentType,
        String notes
) {}
