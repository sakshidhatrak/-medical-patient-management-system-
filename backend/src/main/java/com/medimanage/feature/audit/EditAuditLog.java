package com.medimanage.feature.audit;

import com.medimanage.feature.user.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "edit_audit_logs", indexes = {
    @Index(name = "idx_audit_entity", columnList = "entity_type, entity_id")
})
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class EditAuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "entity_type", nullable = false, length = 50)
    private String entityType;   // "visit" | "patient" | "surgery"

    @Column(name = "entity_id", nullable = false)
    private Long entityId;

    @Column(name = "field_name", nullable = false, length = 100)
    private String fieldName;

    @Column(name = "old_value", columnDefinition = "TEXT")
    private String oldValue;

    @Column(name = "new_value", columnDefinition = "TEXT")
    private String newValue;

    @Column(name = "changed_at", nullable = false)
    private Instant changedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "changed_by_id")
    private User changedBy;
}
