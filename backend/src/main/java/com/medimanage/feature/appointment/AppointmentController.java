package com.medimanage.feature.appointment;

import com.medimanage.common.ApiResponse;
import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.appointment.dto.AppointmentDto;
import com.medimanage.feature.appointment.dto.AppointmentRequest;
import com.medimanage.feature.patient.PatientRepository;
import com.medimanage.feature.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@RestController
@RequiredArgsConstructor
public class AppointmentController {

    private final AppointmentRepository repo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;

    @GetMapping("/patients/{patientId}/appointments")
    public ResponseEntity<ApiResponse<List<AppointmentDto>>> listForPatient(
            @PathVariable Long patientId) {
        return ResponseEntity.ok(ApiResponse.ok(
                repo.findAllByPatientIdAndIsActiveTrue(patientId, Sort.by("scheduledAt").descending())
                        .stream().map(AppointmentDto::from).toList()));
    }

    @GetMapping("/appointments")
    public ResponseEntity<ApiResponse<List<AppointmentDto>>> listByDateRange(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return ResponseEntity.ok(ApiResponse.ok(
                repo.findByDateRange(from, to).stream().map(AppointmentDto::from).toList()));
    }

    @PostMapping("/patients/{patientId}/appointments")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ResponseEntity<ApiResponse<AppointmentDto>> create(
            @PathVariable Long patientId,
            @RequestBody AppointmentRequest req,
            Authentication auth) {
        var patient = patientRepo.findById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        var actor = userRepo.findById((Long) auth.getPrincipal()).orElse(null);
        Appointment a = Appointment.builder()
                .patient(patient)
                .scheduledAt(req.scheduledAt() != null ? req.scheduledAt() : Instant.now())
                .status(req.status() != null ? req.status() : "scheduled")
                .appointmentType(req.appointmentType() != null ? req.appointmentType() : "opd")
                .notes(req.notes())
                .isActive(true)
                .createdBy(actor).updatedBy(actor)
                .build();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Appointment created", AppointmentDto.from(repo.save(a))));
    }

    @PutMapping("/patients/{patientId}/appointments/{appointmentId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ResponseEntity<ApiResponse<AppointmentDto>> update(
            @PathVariable Long patientId,
            @PathVariable Long appointmentId,
            @RequestBody AppointmentRequest req,
            Authentication auth) {
        Appointment a = repo.findByIdAndIsActiveTrue(appointmentId)
                .filter(x -> x.getPatient().getId().equals(patientId))
                .orElseThrow(() -> new ResourceNotFoundException("Appointment", appointmentId));
        var actor = userRepo.findById((Long) auth.getPrincipal()).orElse(null);
        if (req.scheduledAt()     != null) a.setScheduledAt(req.scheduledAt());
        if (req.status()          != null) a.setStatus(req.status());
        if (req.appointmentType() != null) a.setAppointmentType(req.appointmentType());
        if (req.notes()           != null) a.setNotes(req.notes());
        a.setUpdatedBy(actor);
        return ResponseEntity.ok(ApiResponse.ok(AppointmentDto.from(repo.save(a))));
    }

    @DeleteMapping("/patients/{patientId}/appointments/{appointmentId}")
    @PreAuthorize("hasAnyRole('ADMIN','DOCTOR')")
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable Long patientId, @PathVariable Long appointmentId) {
        Appointment a = repo.findByIdAndIsActiveTrue(appointmentId)
                .filter(x -> x.getPatient().getId().equals(patientId))
                .orElseThrow(() -> new ResourceNotFoundException("Appointment", appointmentId));
        a.setActive(false);
        a.setDeletedAt(Instant.now());
        repo.save(a);
        return ResponseEntity.ok(ApiResponse.ok("Deleted", null));
    }
}
