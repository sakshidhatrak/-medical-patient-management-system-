package com.medimanage.feature.visit;

import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.audit.AuditService;
import com.medimanage.feature.patient.Patient;
import com.medimanage.feature.patient.PatientRepository;
import com.medimanage.feature.user.User;
import com.medimanage.feature.user.UserRepository;
import com.medimanage.feature.visit.dto.VisitDto;
import com.medimanage.feature.visit.dto.VisitRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class VisitService {

    private final VisitRepository visitRepo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;
    private final AuditService auditService;

    public List<VisitDto> list(Long patientId) {
        return visitRepo.findAllByPatientIdAndIsActiveTrue(
                        patientId, Sort.by("visitDate").descending())
                .stream().map(VisitDto::from).toList();
    }

    public VisitDto getById(Long patientId, Long visitId) {
        return VisitDto.from(findOrThrow(patientId, visitId));
    }

    @Transactional
    public VisitDto create(Long patientId, VisitRequest req, Long actorId) {
        // Idempotent create: if the mobile client already sent this UUID, return the existing visit.
        if (req.clientId() != null && !req.clientId().isBlank()) {
            var existing = visitRepo.findByClientIdAndPatientId(req.clientId(), patientId);
            if (existing.isPresent()) return VisitDto.from(existing.get());
        }

        Patient patient = patientRepo.findByIdAndIsActiveTrue(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        User actor = userRepo.findById(actorId).orElse(null);

        // Use client-supplied visitType when present; fall back to auto-detection.
        long priorVisits = visitRepo.countByPatientIdAndIsActiveTrue(patientId);
        String resolvedType = (req.visitType() != null && !req.visitType().isBlank())
                ? req.visitType()
                : (priorVisits == 0 ? "OPD" : "FOLLOW_UP");

        Visit v = Visit.builder()
                .patient(patient)
                .clientId(req.clientId())
                .visitDate(Instant.now())   // always server-set IST timestamp
                .visitType(resolvedType)
                .complaints(req.complaints())
                .notes(req.notes())
                .bp(req.bp()).pulse(req.pulse())
                .temperature(req.temperature()).spo2(req.spo2())
                .weight(req.weight()).height(req.height())
                .examPhysical(req.examPhysical())
                .examSystemic(req.examSystemic())
                .examRadiology(req.examRadiology())
                .clinicalImpression(req.clinicalImpression())
                .plan(req.plan())
                .doctorAssigned(req.doctorAssigned())
                .medications(req.medications())
                .examination(req.examination())
                .status(req.status() != null ? req.status() : "draft")
                .isActive(true)
                .createdBy(actor).updatedBy(actor)
                .build();
        return VisitDto.from(visitRepo.save(v));
    }

    @Transactional
    public VisitDto update(Long patientId, Long visitId, VisitRequest req, Long actorId) {
        User actor = userRepo.findById(actorId).orElse(null);
        Visit v = findOrThrow(patientId, visitId);

        List<AuditService.FieldChange> changes = new ArrayList<>();

        if (req.visitType()          != null) { changes.add(AuditService.diff("visitType",          v.getVisitType(),          req.visitType()));          v.setVisitType(req.visitType()); }
        if (req.complaints()         != null) { changes.add(AuditService.diff("complaints",          v.getComplaints(),         req.complaints()));          v.setComplaints(req.complaints()); }
        if (req.notes()              != null) { changes.add(AuditService.diff("notes",               v.getNotes(),              req.notes()));               v.setNotes(req.notes()); }
        if (req.bp()                 != null) { changes.add(AuditService.diff("bp",                  v.getBp(),                 req.bp()));                  v.setBp(req.bp()); }
        if (req.pulse()              != null) { changes.add(AuditService.diff("pulse",               v.getPulse(),              req.pulse()));               v.setPulse(req.pulse()); }
        if (req.temperature()        != null) { changes.add(AuditService.diff("temperature",         v.getTemperature(),        req.temperature()));         v.setTemperature(req.temperature()); }
        if (req.spo2()               != null) { changes.add(AuditService.diff("spo2",                v.getSpo2(),               req.spo2()));                v.setSpo2(req.spo2()); }
        if (req.weight()             != null) { changes.add(AuditService.diff("weight",              v.getWeight(),             req.weight()));              v.setWeight(req.weight()); }
        if (req.height()             != null) { changes.add(AuditService.diff("height",              v.getHeight(),             req.height()));              v.setHeight(req.height()); }
        if (req.examPhysical()       != null) { changes.add(AuditService.diff("examPhysical",        v.getExamPhysical(),       req.examPhysical()));        v.setExamPhysical(req.examPhysical()); }
        if (req.examSystemic()       != null) { changes.add(AuditService.diff("examSystemic",        v.getExamSystemic(),       req.examSystemic()));        v.setExamSystemic(req.examSystemic()); }
        if (req.examRadiology()      != null) { changes.add(AuditService.diff("examRadiology",       v.getExamRadiology(),      req.examRadiology()));       v.setExamRadiology(req.examRadiology()); }
        if (req.clinicalImpression() != null) { changes.add(AuditService.diff("clinicalImpression",  v.getClinicalImpression(), req.clinicalImpression()));  v.setClinicalImpression(req.clinicalImpression()); }
        if (req.plan()               != null) { changes.add(AuditService.diff("plan",                v.getPlan(),               req.plan()));                v.setPlan(req.plan()); }
        if (req.doctorAssigned()     != null) { changes.add(AuditService.diff("doctorAssigned",      v.getDoctorAssigned(),     req.doctorAssigned()));      v.setDoctorAssigned(req.doctorAssigned()); }
        if (req.medications()        != null) { changes.add(AuditService.diff("medications",         v.getMedications(),        req.medications()));         v.setMedications(req.medications()); }
        if (req.examination()        != null) { changes.add(AuditService.diff("examination",         v.getExamination(),        req.examination()));         v.setExamination(req.examination()); }
        if (req.status()             != null) { changes.add(AuditService.diff("status",              v.getStatus(),             req.status()));              v.setStatus(req.status()); }
        if (req.visitDate()          != null)   v.setVisitDate(req.visitDate());

        v.setUpdatedBy(actor);
        VisitDto result = VisitDto.from(visitRepo.save(v));

        auditService.logChanges("visit", visitId, changes, actor);

        return result;
    }

    @Transactional
    public void delete(Long patientId, Long visitId) {
        Visit v = findOrThrow(patientId, visitId);
        v.setActive(false);
        v.setDeletedAt(Instant.now());
        visitRepo.save(v);
    }

    private Visit findOrThrow(Long patientId, Long visitId) {
        return visitRepo.findByIdAndPatientIdAndIsActiveTrue(visitId, patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Visit", visitId));
    }
}
