package com.medimanage.feature.audit;

import com.medimanage.common.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/audit")
@RequiredArgsConstructor
public class AuditController {

    private final AuditService auditService;

    /** GET /audit/all — bulk fetch for mobile cache sync at login. */
    @GetMapping("/all")
    public ResponseEntity<ApiResponse<List<EditAuditLogDto>>> getAllAuditLogs() {
        return ResponseEntity.ok(ApiResponse.ok(auditService.getAllAuditLogs()));
    }

    /** GET /audit/{entityType}/{entityId}  e.g. /audit/visit/42 */
    @GetMapping("/{entityType}/{entityId}")
    public ResponseEntity<ApiResponse<List<EditAuditLogDto>>> getAuditLog(
            @PathVariable String entityType,
            @PathVariable Long entityId) {
        return ResponseEntity.ok(
                ApiResponse.ok(auditService.getAuditLog(entityType, entityId)));
    }
}
