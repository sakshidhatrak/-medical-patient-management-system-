package com.medimanage.feature.appointment;

import com.medimanage.feature.patient.Patient;
import com.medimanage.feature.user.User;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

@Entity
@Table(name = "appointments", indexes = {
    @Index(name = "idx_appt_patient",      columnList = "patient_id"),
    @Index(name = "idx_appt_scheduled_at", columnList = "scheduled_at"),
    @Index(name = "idx_appt_status",       columnList = "status")
})
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Appointment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @Column(name = "scheduled_at", nullable = false)
    private Instant scheduledAt;

    // 'scheduled' | 'confirmed' | 'completed' | 'cancelled' | 'no_show'
    @Column(nullable = false, length = 20)
    private String status = "scheduled";

    // 'opd' | 'follow_up' | 'surgery' | 'review'
    @Column(name = "appointment_type", length = 30)
    private String appointmentType = "opd";

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
