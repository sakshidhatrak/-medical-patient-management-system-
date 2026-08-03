package com.medimanage.feature.examination;

import com.medimanage.feature.patient.Patient;
import com.medimanage.feature.user.User;
import com.medimanage.feature.visit.Visit;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

@Entity
@Table(name = "examinations")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Examination {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "visit_id", nullable = false)
    private Visit visit;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @Column(name = "general_text", columnDefinition = "TEXT")
    private String generalText;

    @Column(name = "motor_text", columnDefinition = "TEXT")
    private String motorText;

    @Column(name = "sensory_text", columnDefinition = "TEXT")
    private String sensoryText;

    @Column(name = "reflexes_text", columnDefinition = "TEXT")
    private String reflexesText;

    @Column(name = "cerebellar_text", columnDefinition = "TEXT")
    private String cerebellarText;

    @Column(name = "special_tests_text", columnDefinition = "TEXT")
    private String specialTestsText;

    @Column(name = "motor_data", columnDefinition = "TEXT")
    private String motorData = "[]";

    @Column(name = "sensory_data", columnDefinition = "TEXT")
    private String sensoryData = "[]";

    @Column(name = "reflex_data", columnDefinition = "TEXT")
    private String reflexData = "{}";

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
