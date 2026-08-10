package com.medimanage.feature.patient.dto;

import jakarta.validation.constraints.NotBlank;

import java.time.LocalDate;

public record PatientRequest(
        @NotBlank String firstName,
        String lastName,
        Integer age,
        LocalDate dateOfBirth,
        String sex,
        String phone,
        String altPhone,
        String email,
        String address,
        String idProofType,
        String idProofNumber,
        String weight,
        String bloodPressure,
        String temperature,
        String allergies,
        String medicalHistory,
        String previousHistory,
        String notes
) {}
