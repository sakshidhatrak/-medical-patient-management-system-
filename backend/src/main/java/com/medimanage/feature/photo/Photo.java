package com.medimanage.feature.photo;

import com.medimanage.feature.patient.Patient;
import com.medimanage.feature.user.User;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

@Entity
@Table(name = "photos",
       indexes = {
           @Index(name = "idx_photos_patient",  columnList = "patient_id"),
           @Index(name = "idx_photos_visit",    columnList = "visit_id"),
           @Index(name = "idx_photos_surgery",  columnList = "surgery_id"),
           @Index(name = "idx_photos_category", columnList = "category"),
       })
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Photo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "patient_id", nullable = false)
    private Patient patient;

    @Column(name = "visit_id")
    private Long visitId;

    @Column(name = "surgery_id")
    private Long surgeryId;

    /** Cloudinary public_id — used to delete the asset */
    @Column(name = "storage_path", nullable = false, length = 500)
    private String storagePath;

    /** Full Cloudinary HTTPS URL for displaying the photo */
    @Column(name = "cloudinary_url", length = 1000)
    private String cloudinaryUrl;

    @Column(nullable = false)
    private String category;

    private String caption;

    @Column(name = "file_size")
    private Integer fileSize;

    @Column(name = "mime_type")
    private String mimeType;

    @Column(name = "is_uploaded", nullable = false)
    private boolean isUploaded = true;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by")
    private User createdBy;

    @CreatedDate
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;
}
