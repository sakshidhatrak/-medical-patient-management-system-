package com.medimanage.feature.vitals;

import com.medimanage.common.ApiResponse;
import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.patient.PatientRepository;
import com.medimanage.feature.vitals.dto.VitalsDto;
import com.medimanage.feature.vitals.dto.VitalsRequest;
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
@RequestMapping("/patients/{patientId}/vitals")
@RequiredArgsConstructor
public class VitalsController {

    private final VitalsRepository repo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;

    @GetMapping
    public ResponseEntity<ApiResponse<List<VitalsDto>>> list(@PathVariable Long patientId) {
        return ResponseEntity.ok(ApiResponse.ok(
                repo.findAllByPatientIdAndIsActiveTrue(patientId, Sort.by("recordedAt").descending())
                        .stream().map(VitalsDto::from).toList()));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ResponseEntity<ApiResponse<VitalsDto>> create(
            @PathVariable Long patientId,
            @RequestBody VitalsRequest req,
            Authentication auth) {
        var patient = patientRepo.findById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        var actor = userRepo.findById((Long) auth.getPrincipal()).orElse(null);
        Vitals v = Vitals.builder()
                .patient(patient)
                .visitId(req.visitId())
                .recordedAt(req.recordedAt() != null ? req.recordedAt() : java.time.Instant.now())
                .bp(req.bp()).pulse(req.pulse()).temperature(req.temperature())
                .spo2(req.spo2()).weight(req.weight()).height(req.height()).rbs(req.rbs())
                .isActive(true)
                .createdBy(actor).updatedBy(actor)
                .build();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Vitals recorded", VitalsDto.from(repo.save(v))));
    }

    @PutMapping("/{vitalsId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ResponseEntity<ApiResponse<VitalsDto>> update(
            @PathVariable Long patientId,
            @PathVariable Long vitalsId,
            @RequestBody VitalsRequest req,
            Authentication auth) {
        Vitals v = repo.findById(vitalsId)
                .filter(x -> x.getPatient().getId().equals(patientId) && x.isActive())
                .orElseThrow(() -> new ResourceNotFoundException("Vitals", vitalsId));
        var actor = userRepo.findById((Long) auth.getPrincipal()).orElse(null);
        if (req.recordedAt()  != null) v.setRecordedAt(req.recordedAt());
        if (req.bp()          != null) v.setBp(req.bp());
        if (req.pulse()       != null) v.setPulse(req.pulse());
        if (req.temperature() != null) v.setTemperature(req.temperature());
        if (req.spo2()        != null) v.setSpo2(req.spo2());
        if (req.weight()      != null) v.setWeight(req.weight());
        if (req.height()      != null) v.setHeight(req.height());
        if (req.rbs()         != null) v.setRbs(req.rbs());
        v.setUpdatedBy(actor);
        return ResponseEntity.ok(ApiResponse.ok(VitalsDto.from(repo.save(v))));
    }

    @DeleteMapping("/{vitalsId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable Long patientId, @PathVariable Long vitalsId) {
        Vitals v = repo.findById(vitalsId)
                .filter(x -> x.getPatient().getId().equals(patientId) && x.isActive())
                .orElseThrow(() -> new ResourceNotFoundException("Vitals", vitalsId));
        v.setActive(false);
        repo.save(v);
        return ResponseEntity.ok(ApiResponse.ok("Deleted", null));
    }
}
