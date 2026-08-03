package com.medimanage.feature.prescription;

import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.patient.PatientRepository;
import com.medimanage.feature.prescription.dto.PrescriptionDto;
import com.medimanage.feature.prescription.dto.PrescriptionRequest;
import com.medimanage.feature.user.UserRepository;
import com.medimanage.feature.visit.VisitRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class PrescriptionService {

    private final PrescriptionRepository repo;
    private final VisitRepository visitRepo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;

    public List<PrescriptionDto> listByVisit(Long patientId, Long visitId) {
        return repo.findAllByVisitId(visitId, Sort.by("createdAt").descending())
                .stream().map(PrescriptionDto::from).toList();
    }

    public List<PrescriptionDto> listByPatient(Long patientId) {
        return repo.findAllByPatientId(patientId, Sort.by("createdAt").descending())
                .stream().map(PrescriptionDto::from).toList();
    }

    @Transactional
    public PrescriptionDto create(Long patientId, Long visitId, PrescriptionRequest req, Long actorId) {
        var visit   = visitRepo.findById(visitId)
                .orElseThrow(() -> new ResourceNotFoundException("Visit", visitId));
        var patient = patientRepo.findById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        var actor   = userRepo.findById(actorId).orElse(null);

        var p = Prescription.builder()
                .visit(visit).patient(patient)
                .text(req.text())
                .drugs(req.drugs() != null ? req.drugs() : "[]")
                .createdBy(actor).updatedBy(actor)
                .build();
        return PrescriptionDto.from(repo.save(p));
    }

    @Transactional
    public PrescriptionDto update(Long id, PrescriptionRequest req, Long actorId) {
        Prescription p = repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Prescription", id));
        var actor = userRepo.findById(actorId).orElse(null);
        if (req.text()  != null) p.setText(req.text());
        if (req.drugs() != null) p.setDrugs(req.drugs());
        p.setUpdatedBy(actor);
        return PrescriptionDto.from(repo.save(p));
    }

    @Transactional
    public void delete(Long id) {
        repo.deleteById(id);
    }
}
