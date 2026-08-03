package com.medimanage.feature.radiology;

import com.medimanage.common.ApiResponse;
import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.patient.PatientRepository;
import com.medimanage.feature.radiology.dto.RadiologyDto;
import com.medimanage.feature.radiology.dto.RadiologyRequest;
import com.medimanage.feature.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class RadiologyController {

    private final RadiologyRepository repo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;

    @GetMapping("/patients/{patientId}/radiology")
    public ResponseEntity<ApiResponse<List<RadiologyDto>>> list(@PathVariable Long patientId) {
        return ResponseEntity.ok(ApiResponse.ok(
                repo.findAllByPatientId(patientId, Sort.by("createdAt").descending())
                        .stream().map(RadiologyDto::from).toList()));
    }

    @PostMapping("/patients/{patientId}/radiology")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<RadiologyDto>> create(
            @PathVariable Long patientId,
            @RequestBody RadiologyRequest req,
            Authentication auth) {
        var patient = patientRepo.findById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        var actor = userRepo.findById((Long) auth.getPrincipal()).orElse(null);
        Radiology r = Radiology.builder()
                .patient(patient)
                .visitId(req.visitId())
                .surgeryId(req.surgeryId())
                .text(req.text())
                .investigations(req.investigations() != null ? req.investigations() : "[]")
                .createdBy(actor).updatedBy(actor)
                .build();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok(RadiologyDto.from(repo.save(r))));
    }

    @DeleteMapping("/radiology/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        repo.deleteById(id);
        return ResponseEntity.ok(ApiResponse.ok("Deleted", null));
    }
}
