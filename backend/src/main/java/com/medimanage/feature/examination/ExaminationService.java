package com.medimanage.feature.examination;

import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.examination.dto.ExaminationDto;
import com.medimanage.feature.examination.dto.ExaminationRequest;
import com.medimanage.feature.patient.PatientRepository;
import com.medimanage.feature.user.UserRepository;
import com.medimanage.feature.visit.VisitRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ExaminationService {

    private final ExaminationRepository repo;
    private final VisitRepository visitRepo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;

    public ExaminationDto getByVisit(Long patientId, Long visitId) {
        return repo.findByVisitId(visitId)
                .map(ExaminationDto::from)
                .orElseThrow(() -> new ResourceNotFoundException("Examination", visitId));
    }

    @Transactional
    public ExaminationDto upsert(Long patientId, Long visitId, ExaminationRequest req, Long actorId) {
        var visit   = visitRepo.findById(visitId)
                .orElseThrow(() -> new ResourceNotFoundException("Visit", visitId));
        var patient = patientRepo.findById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        var actor   = userRepo.findById(actorId).orElse(null);

        Examination exam = repo.findByVisitId(visitId).orElse(
                Examination.builder().visit(visit).patient(patient).build());

        if (req.generalText()       != null) exam.setGeneralText(req.generalText());
        if (req.motorText()         != null) exam.setMotorText(req.motorText());
        if (req.sensoryText()       != null) exam.setSensoryText(req.sensoryText());
        if (req.reflexesText()      != null) exam.setReflexesText(req.reflexesText());
        if (req.cerebellarText()    != null) exam.setCerebellarText(req.cerebellarText());
        if (req.specialTestsText()  != null) exam.setSpecialTestsText(req.specialTestsText());
        if (req.motorData()         != null) exam.setMotorData(req.motorData());
        if (req.sensoryData()       != null) exam.setSensoryData(req.sensoryData());
        if (req.reflexData()        != null) exam.setReflexData(req.reflexData());
        exam.setUpdatedBy(actor);
        if (exam.getCreatedBy() == null) exam.setCreatedBy(actor);

        return ExaminationDto.from(repo.save(exam));
    }
}
