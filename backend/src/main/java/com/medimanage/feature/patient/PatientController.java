package com.medimanage.feature.patient;

import com.medimanage.common.ApiResponse;
import com.medimanage.common.PageResponse;
import com.medimanage.feature.patient.dto.PatientDto;
import com.medimanage.feature.patient.dto.PatientRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/patients")
@RequiredArgsConstructor
public class PatientController {

    private final PatientService service;

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<PatientDto>>> list(
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "1")  int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.ok(service.list(search, page, size)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<PatientDto>> get(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getById(id)));
    }

    @GetMapping("/duplicates")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<List<PatientDto>>> duplicates(@RequestParam String name) {
        return ResponseEntity.ok(ApiResponse.ok(service.findDuplicates(name)));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<PatientDto>> create(
            @Valid @RequestBody PatientRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Patient registered", service.create(req, actorId)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<PatientDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody PatientRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.ok(ApiResponse.ok(service.update(id, req, actorId)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok("Patient deleted", null));
    }
}
