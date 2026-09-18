package com.medimanage.feature.audit;

import java.time.Instant;

public record EditAuditLogDto(
        Long id,
        String entityType,
        Long entityId,
        String fieldName,
        String oldValue,
        String newValue,
        Instant changedAt,
        String changedByName
) {
    public static EditAuditLogDto from(EditAuditLog log) {
        String name = null;
        if (log.getChangedBy() != null) {
            name = (log.getChangedBy().getFirstName()
                    + (log.getChangedBy().getLastName() != null ? " " + log.getChangedBy().getLastName() : ""))
                    .trim();
        }
        return new EditAuditLogDto(
                log.getId(),
                log.getEntityType(),
                log.getEntityId(),
                log.getFieldName(),
                log.getOldValue(),
                log.getNewValue(),
                log.getChangedAt(),
                name
        );
    }
}
