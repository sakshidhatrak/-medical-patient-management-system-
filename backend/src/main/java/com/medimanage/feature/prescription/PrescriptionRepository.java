package com.medimanage.feature.prescription;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PrescriptionRepository extends JpaRepository<Prescription, Long> {
    List<Prescription> findAllByVisitId(Long visitId, Sort sort);
    List<Prescription> findAllByPatientId(Long patientId, Sort sort);
}
