package com.medimanage.feature.patient;

import com.medimanage.feature.user.User;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "patients")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Patient {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String prn;

    // ── Identity ────────────────────────────────────────────────────
    @Column(name = "first_name", nullable = false)
    private String firstName;

    @Column(name = "last_name")
    private String lastName;

    private Integer age;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    private String sex;

    // ── Contact ─────────────────────────────────────────────────────
    private String phone;

    @Column(name = "alt_phone")
    private String altPhone;

    private String email;

    private String address;

    // ── ID Proof ────────────────────────────────────────────────────
    @Column(name = "id_proof_type")
    private String idProofType;

    @Column(name = "id_proof_number")
    private String idProofNumber;

    // ── Registration Vitals ─────────────────────────────────────────
    private String weight;

    @Column(name = "blood_pressure")
    private String bloodPressure;

    private String temperature;

    // ── History ─────────────────────────────────────────────────────
    private String allergies;

    @Column(name = "medical_history")
    private String medicalHistory;

    @Column(name = "previous_history")
    private String previousHistory;

    // ── Clinical snapshot ────────────────────────────────────────────
    @Column(name = "chief_complaint")
    private String chiefComplaint;

    @Column(name = "exam_general", columnDefinition = "TEXT")
    private String examGeneral;

    @Column(name = "exam_neurological", columnDefinition = "TEXT")
    private String examNeurological;

    @Column(name = "clinical_diagnosis", columnDefinition = "TEXT")
    private String clinicalDiagnosis;

    @Column(columnDefinition = "TEXT")
    private String imaging;

    @Column(name = "other_investigations", columnDefinition = "TEXT")
    private String otherInvestigations;

    @Column(columnDefinition = "TEXT")
    private String impression;

    @Column(columnDefinition = "TEXT")
    private String plan;

    @Column(columnDefinition = "TEXT")
    private String treatment;

    @Column(name = "treatment_notes", columnDefinition = "TEXT")
    private String treatmentNotes;

    @Column(columnDefinition = "TEXT")
    private String advice;

    // ── Admin ────────────────────────────────────────────────────────
    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "is_active", nullable = false)
    private boolean isActive = true;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by")
    private User createdBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "updated_by")
    private User updatedBy;

    @CreatedDate
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;
}
