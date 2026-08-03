package com.medimanage.feature.photo;

import com.medimanage.common.ApiResponse;
import com.medimanage.feature.photo.dto.PhotoDto;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.net.MalformedURLException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

@RestController
@RequiredArgsConstructor
public class PhotoController {

    private final PhotoService service;

    @Value("${app.upload-dir:./uploads}")
    private String uploadDir;

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

    // ── Serve file ────────────────────────────────────────────────────

    @GetMapping("/photos/file/**")
    public ResponseEntity<Resource> serveFile(HttpServletRequest request) {
        String requestPath = request.getRequestURI();
        String relativePath = requestPath.substring(requestPath.indexOf("/photos/file/") + "/photos/file/".length());

        try {
            Path filePath = Paths.get(uploadDir).resolve(relativePath).normalize();
            Resource resource = new UrlResource(filePath.toUri());
            if (!resource.exists() || !resource.isReadable()) {
                return ResponseEntity.notFound().build();
            }
            String contentType = determineContentType(relativePath);
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                    .contentType(MediaType.parseMediaType(contentType))
                    .body(resource);
        } catch (MalformedURLException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    // ── Delete ────────────────────────────────────────────────────────

    @DeleteMapping("/photos/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok("Photo deleted", null));
    }

    private String determineContentType(String path) {
        String lower = path.toLowerCase();
        if (lower.endsWith(".png"))  return "image/png";
        if (lower.endsWith(".pdf"))  return "application/pdf";
        if (lower.endsWith(".docx")) return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
        if (lower.endsWith(".doc"))  return "application/msword";
        if (lower.endsWith(".xlsx")) return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
        return "image/jpeg";
    }
}
