package com.medimanage.feature.radiology;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface RadiologyRepository extends JpaRepository<Radiology, Long> {
    List<Radiology> findAllByPatientIdAndIsActiveTrue(Long patientId, Sort sort);
    List<Radiology> findAllByVisitIdAndIsActiveTrue(Long visitId);
    Optional<Radiology> findByIdAndIsActiveTrue(Long id);
}
