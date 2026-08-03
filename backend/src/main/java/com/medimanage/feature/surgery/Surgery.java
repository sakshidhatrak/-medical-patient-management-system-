package com.medimanage.feature.surgery;

import com.medimanage.feature.patient.Patient;
import com.medimanage.feature.user.User;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

@Entity
@Table(name = "surgeries")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Surgery {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @Column(name = "surgery_date", nullable = false)
    private Instant surgeryDate;

    @Column(name = "your_role")
    private String yourRole;

    @Column(name = "pre_op_diagnosis", columnDefinition = "TEXT")
    private String preOpDiagnosis;

    @Column(columnDefinition = "TEXT")
    private String procedure;

    @Column(name = "primary_surgeon")
    private String primarySurgeon;

    @Column(name = "assistant_surgeons")
    private String assistantSurgeons;

    @Column(name = "anesthesia_type")
    private String anesthesiaType;

    private String anesthesiologist;

    @Column(columnDefinition = "TEXT")
    private String implants;

    @Column(name = "implant_details", columnDefinition = "TEXT")
    private String implantDetails = "[]";

    @Column(name = "intraop_findings", columnDefinition = "TEXT")
    private String intraopFindings;

    @Column(name = "ot_notes", columnDefinition = "TEXT")
    private String otNotes;

    @Column(columnDefinition = "TEXT")
    private String complications;

    @Column(name = "post_op_plan", columnDefinition = "TEXT")
    private String postOpPlan;

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
