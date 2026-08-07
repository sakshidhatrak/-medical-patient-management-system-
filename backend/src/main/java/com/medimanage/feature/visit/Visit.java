package com.medimanage.feature.visit;

import com.medimanage.feature.patient.Patient;
import com.medimanage.feature.user.User;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

@Entity
@Table(name = "visits")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Visit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @Column(name = "visit_date", nullable = false)
    private Instant visitDate;

    @Column(name = "visit_type", nullable = false)
    private String visitType;

    // Client-supplied UUID for idempotent create (mobile offline sync).
    @Column(name = "client_id", unique = true)
    private String clientId;

    // ── Visit fields ────────────────────────────────────────────────
    @Column(columnDefinition = "TEXT")
    private String complaints;

    @Column(columnDefinition = "TEXT")
    private String notes;

    // ── Vitals ──────────────────────────────────────────────────────
    private String bp;
    private String pulse;
    private String temperature;
    private String spo2;
    private String weight;
    private String height;

    // ── Examination ─────────────────────────────────────────────────
    @Column(name = "exam_physical", columnDefinition = "TEXT")
    private String examPhysical;

    @Column(name = "exam_systemic", columnDefinition = "TEXT")
    private String examSystemic;

    @Column(name = "exam_radiology", columnDefinition = "TEXT")
    private String examRadiology;

    // ── Clinical ────────────────────────────────────────────────────
    @Column(name = "clinical_impression", columnDefinition = "TEXT")
    private String clinicalImpression;

    @Column(columnDefinition = "TEXT")
    private String plan;

    @Column(name = "doctor_assigned")
    private String doctorAssigned;

    @Column(columnDefinition = "TEXT")
    private String medications;

    @Column(columnDefinition = "TEXT")
    private String examination;

    // ── Admin ────────────────────────────────────────────────────────
    @Column(nullable = false)
    private String status = "draft";

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
