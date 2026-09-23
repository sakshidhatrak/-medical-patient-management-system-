package com.medimanage.feature.appointment.dto;

import com.medimanage.feature.appointment.Appointment;

import java.time.Instant;

public record AppointmentDto(
        Long id,
        Long patientId,
        String patientName,
        Instant scheduledAt,
        String status,
        String appointmentType,
        String notes,
        Instant createdAt,
        Instant updatedAt
) {
    public static AppointmentDto from(Appointment a) {
        String name = a.getPatient().getLastName() == null || a.getPatient().getLastName().isBlank()
                ? a.getPatient().getFirstName()
                : a.getPatient().getFirstName() + " " + a.getPatient().getLastName();
        return new AppointmentDto(
                a.getId(),
                a.getPatient().getId(),
                name,
                a.getScheduledAt(),
                a.getStatus(),
                a.getAppointmentType(),
                a.getNotes(),
                a.getCreatedAt(),
                a.getUpdatedAt()
        );
    }
}
