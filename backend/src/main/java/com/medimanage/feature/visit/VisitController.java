package com.medimanage.feature.visit;

import com.medimanage.common.ApiResponse;
import com.medimanage.feature.visit.dto.VisitDto;
import com.medimanage.feature.visit.dto.VisitRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/patients/{patientId}/visits")
@RequiredArgsConstructor
public class VisitController {

    private final VisitService service;

    @GetMapping
    public ResponseEntity<ApiResponse<List<VisitDto>>> list(@PathVariable Long patientId) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(patientId)));
    }

    @GetMapping("/{visitId}")
    public ResponseEntity<ApiResponse<VisitDto>> get(
            @PathVariable Long patientId,
            @PathVariable Long visitId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getById(patientId, visitId)));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<VisitDto>> create(
            @PathVariable Long patientId,
            @RequestBody VisitRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Visit created", service.create(patientId, req, actorId)));
    }

    @PutMapping("/{visitId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<VisitDto>> update(
            @PathVariable Long patientId,
            @PathVariable Long visitId,
            @RequestBody VisitRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.ok(ApiResponse.ok(service.update(patientId, visitId, req, actorId)));
    }

    @DeleteMapping("/{visitId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable Long patientId,
            @PathVariable Long visitId) {
        service.delete(patientId, visitId);
        return ResponseEntity.ok(ApiResponse.ok("Visit deleted", null));
    }
}
