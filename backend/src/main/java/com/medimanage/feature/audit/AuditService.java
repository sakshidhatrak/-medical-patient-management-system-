package com.medimanage.feature.audit;

import com.medimanage.feature.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class AuditService {

    private final EditAuditLogRepository repo;

    /** Persist all non-null FieldChange entries as audit log rows. */
    @Transactional
    public void logChanges(String entityType, Long entityId,
                           List<FieldChange> changes, User actor) {
        Instant now = Instant.now();
        changes.stream()
                .filter(Objects::nonNull)
                .forEach(c -> repo.save(
                        EditAuditLog.builder()
                                .entityType(entityType)
                                .entityId(entityId)
                                .fieldName(c.fieldName())
                                .oldValue(c.oldValue())
                                .newValue(c.newValue())
                                .changedAt(now)
                                .changedBy(actor)
                                .build()));
    }

    public List<EditAuditLogDto> getAuditLog(String entityType, Long entityId) {
        return repo.findAllByEntityTypeAndEntityIdOrderByChangedAtDesc(entityType, entityId)
                .stream().map(EditAuditLogDto::from).toList();
    }

    /**
     * Returns a FieldChange if old != new, null otherwise.
     * Treats null and empty string as equivalent to avoid spurious audit entries.
     */
    public static FieldChange diff(String fieldName, String oldVal, String newVal) {
        String old = nullToEmpty(oldVal);
        String nw  = nullToEmpty(newVal);
        if (old.equals(nw)) return null;
        return new FieldChange(fieldName, oldVal, newVal);
    }

    private static String nullToEmpty(String s) {
        return s == null ? "" : s.trim();
    }

    public record FieldChange(String fieldName, String oldValue, String newValue) {}
}
