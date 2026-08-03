package com.medimanage.feature.visit;

import com.medimanage.common.exception.ResourceNotFoundException;
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
import java.util.List;

@Service
@RequiredArgsConstructor
public class VisitService {

    private final VisitRepository visitRepo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;

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
        Patient patient = patientRepo.findByIdAndIsActiveTrue(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        User actor = userRepo.findById(actorId).orElse(null);

        Visit v = Visit.builder()
                .patient(patient)
                .visitDate(req.visitDate() != null ? req.visitDate() : Instant.now())
                .visitType(req.visitType() != null ? req.visitType() : "opd")
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

        if (req.visitDate()        != null) v.setVisitDate(req.visitDate());
        if (req.visitType()        != null) v.setVisitType(req.visitType());
        if (req.complaints()       != null) v.setComplaints(req.complaints());
        if (req.notes()            != null) v.setNotes(req.notes());
        if (req.bp()               != null) v.setBp(req.bp());
        if (req.pulse()            != null) v.setPulse(req.pulse());
        if (req.temperature()      != null) v.setTemperature(req.temperature());
        if (req.spo2()             != null) v.setSpo2(req.spo2());
        if (req.weight()           != null) v.setWeight(req.weight());
        if (req.height()           != null) v.setHeight(req.height());
        if (req.examPhysical()     != null) v.setExamPhysical(req.examPhysical());
        if (req.examSystemic()     != null) v.setExamSystemic(req.examSystemic());
        if (req.examRadiology()    != null) v.setExamRadiology(req.examRadiology());
        if (req.clinicalImpression() != null) v.setClinicalImpression(req.clinicalImpression());
        if (req.plan()             != null) v.setPlan(req.plan());
        if (req.doctorAssigned()   != null) v.setDoctorAssigned(req.doctorAssigned());
        if (req.medications()      != null) v.setMedications(req.medications());
        if (req.examination()      != null) v.setExamination(req.examination());
        if (req.status()           != null) v.setStatus(req.status());
        v.setUpdatedBy(actor);
        return VisitDto.from(visitRepo.save(v));
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
