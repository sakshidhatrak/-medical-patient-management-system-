package com.medimanage.feature.prescription;

import com.medimanage.common.ApiResponse;
import com.medimanage.feature.prescription.dto.PrescriptionDto;
import com.medimanage.feature.prescription.dto.PrescriptionRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class PrescriptionController {

    private final PrescriptionService service;

    @GetMapping("/patients/{patientId}/visits/{visitId}/prescriptions")
    public ResponseEntity<ApiResponse<List<PrescriptionDto>>> listByVisit(
            @PathVariable Long patientId, @PathVariable Long visitId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listByVisit(patientId, visitId)));
    }

    @GetMapping("/patients/{patientId}/prescriptions")
    public ResponseEntity<ApiResponse<List<PrescriptionDto>>> listByPatient(@PathVariable Long patientId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listByPatient(patientId)));
    }

    @PostMapping("/patients/{patientId}/visits/{visitId}/prescriptions")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<PrescriptionDto>> create(
            @PathVariable Long patientId,
            @PathVariable Long visitId,
            @RequestBody PrescriptionRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Prescription saved", service.create(patientId, visitId, req, actorId)));
    }

    @PutMapping("/prescriptions/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<PrescriptionDto>> update(
            @PathVariable Long id,
            @RequestBody PrescriptionRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.ok(ApiResponse.ok(service.update(id, req, actorId)));
    }

    @DeleteMapping("/prescriptions/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok("Prescription deleted", null));
    }
}
