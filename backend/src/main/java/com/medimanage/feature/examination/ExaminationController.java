package com.medimanage.feature.examination;

import com.medimanage.common.ApiResponse;
import com.medimanage.feature.examination.dto.ExaminationDto;
import com.medimanage.feature.examination.dto.ExaminationRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/patients/{patientId}/visits/{visitId}/examination")
@RequiredArgsConstructor
public class ExaminationController {

    private final ExaminationService service;

    @GetMapping
    public ResponseEntity<ApiResponse<ExaminationDto>> get(
            @PathVariable Long patientId, @PathVariable Long visitId) {
        return ResponseEntity.ok(ApiResponse.ok(service.getByVisit(patientId, visitId)));
    }

    @PutMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<ExaminationDto>> upsert(
            @PathVariable Long patientId,
            @PathVariable Long visitId,
            @RequestBody ExaminationRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.ok(ApiResponse.ok(service.upsert(patientId, visitId, req, actorId)));
    }
}
