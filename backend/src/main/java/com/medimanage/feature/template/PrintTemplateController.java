package com.medimanage.feature.template;

import com.medimanage.common.ApiResponse;
import com.medimanage.feature.template.dto.PrintTemplateDto;
import com.medimanage.feature.template.dto.PrintTemplateRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/templates")
@RequiredArgsConstructor
public class PrintTemplateController {

    private final PrintTemplateService service;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PrintTemplateDto>>> list() {
        return ResponseEntity.ok(ApiResponse.ok(service.listAll()));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<PrintTemplateDto>> get(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.ok(service.getById(id)));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<PrintTemplateDto>> create(
            @RequestBody PrintTemplateRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Template created", service.create(req, actorId)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<PrintTemplateDto>> update(
            @PathVariable Long id,
            @RequestBody PrintTemplateRequest req,
            Authentication auth) {
        Long actorId = (Long) auth.getPrincipal();
        return ResponseEntity.ok(ApiResponse.ok(service.update(id, req, actorId)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.ok("Template deleted", null));
    }
}
