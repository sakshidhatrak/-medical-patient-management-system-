package com.medimanage.feature.surgery;

import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.patient.PatientRepository;
import com.medimanage.feature.surgery.dto.SurgeryDto;
import com.medimanage.feature.surgery.dto.SurgeryRequest;
import com.medimanage.feature.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SurgeryService {

    private final SurgeryRepository repo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;

    public List<SurgeryDto> list(Long patientId) {
        return repo.findAllByPatientIdAndIsActiveTrue(patientId, Sort.by("surgeryDate").descending())
                .stream().map(SurgeryDto::from).toList();
    }

    public SurgeryDto getById(Long patientId, Long id) {
        return SurgeryDto.from(findOrThrow(patientId, id));
    }

    @Transactional
    public SurgeryDto create(Long patientId, SurgeryRequest req, Long actorId) {
        var patient = patientRepo.findByIdAndIsActiveTrue(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        var actor = userRepo.findById(actorId).orElse(null);

        Surgery s = Surgery.builder()
                .patient(patient)
                .surgeryDate(req.surgeryDate() != null ? req.surgeryDate() : Instant.now())
                .yourRole(req.yourRole())
                .preOpDiagnosis(req.preOpDiagnosis())
                .procedure(req.procedure())
                .primarySurgeon(req.primarySurgeon())
                .assistantSurgeons(req.assistantSurgeons())
                .anesthesiaType(req.anesthesiaType())
                .anesthesiologist(req.anesthesiologist())
                .implants(req.implants())
                .implantDetails(req.implantDetails() != null ? req.implantDetails() : "[]")
                .intraopFindings(req.intraopFindings())
                .otNotes(req.otNotes())
                .complications(req.complications())
                .postOpPlan(req.postOpPlan())
                .status(req.status() != null ? req.status() : "draft")
                .isActive(true)
                .createdBy(actor).updatedBy(actor)
                .build();
        return SurgeryDto.from(repo.save(s));
    }

    @Transactional
    public SurgeryDto update(Long patientId, Long id, SurgeryRequest req, Long actorId) {
        var actor = userRepo.findById(actorId).orElse(null);
        Surgery s = findOrThrow(patientId, id);
        if (req.surgeryDate()       != null) s.setSurgeryDate(req.surgeryDate());
        if (req.yourRole()          != null) s.setYourRole(req.yourRole());
        if (req.preOpDiagnosis()    != null) s.setPreOpDiagnosis(req.preOpDiagnosis());
        if (req.procedure()         != null) s.setProcedure(req.procedure());
        if (req.primarySurgeon()    != null) s.setPrimarySurgeon(req.primarySurgeon());
        if (req.assistantSurgeons() != null) s.setAssistantSurgeons(req.assistantSurgeons());
        if (req.anesthesiaType()    != null) s.setAnesthesiaType(req.anesthesiaType());
        if (req.anesthesiologist()  != null) s.setAnesthesiologist(req.anesthesiologist());
        if (req.implants()          != null) s.setImplants(req.implants());
        if (req.implantDetails()    != null) s.setImplantDetails(req.implantDetails());
        if (req.intraopFindings()   != null) s.setIntraopFindings(req.intraopFindings());
        if (req.otNotes()           != null) s.setOtNotes(req.otNotes());
        if (req.complications()     != null) s.setComplications(req.complications());
        if (req.postOpPlan()        != null) s.setPostOpPlan(req.postOpPlan());
        if (req.status()            != null) s.setStatus(req.status());
        s.setUpdatedBy(actor);
        return SurgeryDto.from(repo.save(s));
    }

    @Transactional
    public void delete(Long patientId, Long id) {
        Surgery s = findOrThrow(patientId, id);
        s.setActive(false);
        s.setDeletedAt(Instant.now());
        repo.save(s);
    }

    private Surgery findOrThrow(Long patientId, Long id) {
        return repo.findByIdAndPatientIdAndIsActiveTrue(id, patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Surgery", id));
    }
}
