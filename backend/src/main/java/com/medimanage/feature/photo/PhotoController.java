package com.medimanage.feature.photo;

import com.medimanage.common.ApiResponse;
import com.medimanage.feature.photo.dto.PhotoDto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class PhotoController {

    private final PhotoService service;

    // ── List ──────────────────────────────────────────────────────────

    @GetMapping("/patients/{patientId}/photos")
    public ResponseEntity<ApiResponse<List<PhotoDto>>> listByPatient(
            @PathVariable Long patientId,
            @RequestParam(required = false) String category) {
        return ResponseEntity.ok(ApiResponse.ok(service.listByPatient(patientId, category)));
    }

    @GetMapping("/patients/{patientId}/visits/{visitId}/photos")
    public ResponseEntity<ApiResponse<List<PhotoDto>>> listByVisit(
            @PathVariable Long patientId,
            @PathVariable Long visitId) {
        return ResponseEntity.ok(ApiResponse.ok(service.listByVisit(visitId)));
    }

    // ── Upload ────────────────────────────────────────────────────────

    @PostMapping(value = "/patients/{patientId}/photos/upload",
                 consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<PhotoDto>> upload(
            @PathVariable Long patientId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) String caption,
            @RequestParam(required = false) Long visitId,
            @RequestParam(required = false) Long surgeryId,
            Authentication auth) throws Exception {
        Long actorId = (Long) auth.getPrincipal();
        PhotoDto dto = service.uploadFile(
                patientId, visitId, surgeryId, file, category, caption, actorId);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(dto));
    }

    // ── Delete ────────────────────────────────────────────────────────

    @DeleteMapping("/photos/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok("Photo deleted", null));
    }

}
