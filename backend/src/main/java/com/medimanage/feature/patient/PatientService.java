package com.medimanage.feature.patient;

import com.medimanage.common.PageResponse;
import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.patient.dto.PatientDto;
import com.medimanage.feature.patient.dto.PatientRequest;
import com.medimanage.feature.user.User;
import com.medimanage.feature.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PatientService {

    private final PatientRepository repo;
    private final UserRepository userRepo;

    public PageResponse<PatientDto> list(String search, int page, int size) {
        var pageable = PageRequest.of(page - 1, size, Sort.by("createdAt").descending());
        var result = (search == null || search.isBlank())
                ? repo.findAllByIsActiveTrue(pageable)
                : repo.search(search, pageable);
        return new PageResponse<>(result.map(PatientDto::from));
    }

    public PatientDto getById(Long id) {
        return PatientDto.from(findOrThrow(id));
    }

    public List<PatientDto> findDuplicates(String name) {
        return repo.findDuplicatesByName(name, PageRequest.of(0, 5))
                .stream().map(PatientDto::from).toList();
    }

    @Transactional
    public PatientDto create(PatientRequest req, Long actorId) {
        User actor = userRepo.findById(actorId).orElse(null);
        Patient p = Patient.builder()
                .prn(generatePrn())
                .firstName(req.firstName())
                .lastName(req.lastName() != null ? req.lastName() : "")
                .age(req.age())
                .dateOfBirth(req.dateOfBirth())
                .sex(req.sex())
                .phone(req.phone())
                .altPhone(req.altPhone())
                .email(req.email())
                .address(req.address())
                .idProofType(req.idProofType())
                .idProofNumber(req.idProofNumber())
                .weight(req.weight())
                .bloodPressure(req.bloodPressure())
                .temperature(req.temperature())
                .allergies(req.allergies())
                .medicalHistory(req.medicalHistory())
                .previousHistory(req.previousHistory())
                .chiefComplaint(req.chiefComplaint())
                .examGeneral(req.examGeneral())
                .examNeurological(req.examNeurological())
                .clinicalDiagnosis(req.clinicalDiagnosis())
                .imaging(req.imaging())
                .otherInvestigations(req.otherInvestigations())
                .impression(req.impression())
                .plan(req.plan())
                .treatment(req.treatment())
                .treatmentNotes(req.treatmentNotes())
                .advice(req.advice())
                .notes(req.notes())
                .isActive(true)
                .createdBy(actor)
                .updatedBy(actor)
                .build();
        return PatientDto.from(repo.save(p));
    }

    @Transactional
    public PatientDto update(Long id, PatientRequest req, Long actorId) {
        User actor = userRepo.findById(actorId).orElse(null);
        Patient p = findOrThrow(id);
        p.setFirstName(req.firstName());
        p.setLastName(req.lastName() != null ? req.lastName() : p.getLastName());
        p.setAge(req.age() != null ? req.age() : p.getAge());
        p.setDateOfBirth(req.dateOfBirth() != null ? req.dateOfBirth() : p.getDateOfBirth());
        p.setSex(req.sex() != null ? req.sex() : p.getSex());
        p.setPhone(req.phone() != null ? req.phone() : p.getPhone());
        p.setAltPhone(req.altPhone() != null ? req.altPhone() : p.getAltPhone());
        p.setEmail(req.email() != null ? req.email() : p.getEmail());
        p.setAddress(req.address() != null ? req.address() : p.getAddress());
        p.setIdProofType(req.idProofType() != null ? req.idProofType() : p.getIdProofType());
        p.setIdProofNumber(req.idProofNumber() != null ? req.idProofNumber() : p.getIdProofNumber());
        p.setWeight(req.weight() != null ? req.weight() : p.getWeight());
        p.setBloodPressure(req.bloodPressure() != null ? req.bloodPressure() : p.getBloodPressure());
        p.setTemperature(req.temperature() != null ? req.temperature() : p.getTemperature());
        p.setAllergies(req.allergies() != null ? req.allergies() : p.getAllergies());
        p.setMedicalHistory(req.medicalHistory() != null ? req.medicalHistory() : p.getMedicalHistory());
        p.setPreviousHistory(req.previousHistory() != null ? req.previousHistory() : p.getPreviousHistory());
        p.setChiefComplaint(req.chiefComplaint() != null ? req.chiefComplaint() : p.getChiefComplaint());
        p.setExamGeneral(req.examGeneral() != null ? req.examGeneral() : p.getExamGeneral());
        p.setExamNeurological(req.examNeurological() != null ? req.examNeurological() : p.getExamNeurological());
        p.setClinicalDiagnosis(req.clinicalDiagnosis() != null ? req.clinicalDiagnosis() : p.getClinicalDiagnosis());
        p.setImaging(req.imaging() != null ? req.imaging() : p.getImaging());
        p.setOtherInvestigations(req.otherInvestigations() != null ? req.otherInvestigations() : p.getOtherInvestigations());
        p.setImpression(req.impression() != null ? req.impression() : p.getImpression());
        p.setPlan(req.plan() != null ? req.plan() : p.getPlan());
        p.setTreatment(req.treatment() != null ? req.treatment() : p.getTreatment());
        p.setTreatmentNotes(req.treatmentNotes() != null ? req.treatmentNotes() : p.getTreatmentNotes());
        p.setAdvice(req.advice() != null ? req.advice() : p.getAdvice());
        p.setNotes(req.notes() != null ? req.notes() : p.getNotes());
        p.setUpdatedBy(actor);
        return PatientDto.from(repo.save(p));
    }

    @Transactional
    public void delete(Long id) {
        Patient p = findOrThrow(id);
        p.setActive(false);
        p.setDeletedAt(Instant.now());
        repo.save(p);
    }

    private Patient findOrThrow(Long id) {
        return repo.findByIdAndIsActiveTrue(id)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", id));
    }

    private String generatePrn() {
        var f = DateTimeFormatter.ofPattern("ddMMyyHHmmss");
        return LocalDateTime.now().format(f);
    }
}
