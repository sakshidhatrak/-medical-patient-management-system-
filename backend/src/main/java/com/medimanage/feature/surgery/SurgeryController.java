package com.medimanage.feature.surgery;

import com.medimanage.common.ApiResponse;
import com.medimanage.feature.surgery.dto.SurgeryDto;
import com.medimanage.feature.surgery.dto.SurgeryRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/patients/{patientId}/surgeries")
@RequiredArgsConstructor
public class SurgeryController {

    private final SurgeryService service;

    @GetMapping
    public ResponseEntity<ApiResponse<List<SurgeryDto>>> list(@PathVariable Long patientId) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(patientId)));
    }

    @GetMapping("/{surgeryId}")
    public ResponseEntity<ApiResponse<SurgeryDto>> get(
            @PathVariable Long patientId, @PathVariable Long surgeryId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getById(patientId, surgeryId)));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<SurgeryDto>> create(
            @PathVariable Long patientId,
            @RequestBody SurgeryRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Surgery created", service.create(patientId, req, actorId)));
    }

    @PutMapping("/{surgeryId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<SurgeryDto>> update(
            @PathVariable Long patientId,
            @PathVariable Long surgeryId,
            @RequestBody SurgeryRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.ok(ApiResponse.ok(service.update(patientId, surgeryId, req, actorId)));
    }

    @DeleteMapping("/{surgeryId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable Long patientId, @PathVariable Long surgeryId) {
        service.delete(patientId, surgeryId);
        return ResponseEntity.ok(ApiResponse.ok("Surgery deleted", null));
    }
}
