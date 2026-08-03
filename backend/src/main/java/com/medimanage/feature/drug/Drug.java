package com.medimanage.feature.drug;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

@Entity
@Table(name = "drugs_master")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Drug {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "generic_name", nullable = false)
    private String genericName;

    @Column(name = "brand_names", columnDefinition = "TEXT")
    private String brandNames;

    private String composition;
    private String category;

    @Column(name = "default_dose")
    private String defaultDose;

    @Column(name = "default_frequency")
    private String defaultFrequency;

    @Column(name = "default_duration")
    private String defaultDuration;

    @Column(name = "is_active", nullable = false)
    private boolean isActive = true;

    @CreatedDate
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;
}
