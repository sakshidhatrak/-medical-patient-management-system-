package com.medimanage.feature.patient.dto;

import com.medimanage.feature.patient.Patient;

import java.time.Instant;
import java.time.LocalDate;

public record PatientDto(
        Long id, String prn,
        String firstName, String lastName, String fullName,
        Integer age, LocalDate dateOfBirth, String sex,
        String phone, String altPhone, String email, String address,
        String idProofType, String idProofNumber,
        String weight, String bloodPressure, String temperature,
        String allergies, String medicalHistory, String previousHistory,
        String chiefComplaint,
        String examGeneral, String examNeurological,
        String clinicalDiagnosis, String imaging, String otherInvestigations,
        String impression, String plan, String treatment,
        String treatmentNotes, String advice,
        String notes,
        boolean isActive,
        Instant createdAt, Instant updatedAt
) {
    public static PatientDto from(Patient p) {
        String full = (p.getLastName() == null || p.getLastName().isBlank())
                ? p.getFirstName()
                : p.getFirstName() + " " + p.getLastName();
        return new PatientDto(
                p.getId(), p.getPrn(),
                p.getFirstName(), p.getLastName(), full,
                p.getAge(), p.getDateOfBirth(), p.getSex(),
                p.getPhone(), p.getAltPhone(), p.getEmail(), p.getAddress(),
                p.getIdProofType(), p.getIdProofNumber(),
                p.getWeight(), p.getBloodPressure(), p.getTemperature(),
                p.getAllergies(), p.getMedicalHistory(), p.getPreviousHistory(),
                p.getChiefComplaint(),
                p.getExamGeneral(), p.getExamNeurological(),
                p.getClinicalDiagnosis(), p.getImaging(), p.getOtherInvestigations(),
                p.getImpression(), p.getPlan(), p.getTreatment(),
                p.getTreatmentNotes(), p.getAdvice(),
                p.getNotes(),
                p.isActive(),
                p.getCreatedAt(), p.getUpdatedAt()
        );
    }
}
