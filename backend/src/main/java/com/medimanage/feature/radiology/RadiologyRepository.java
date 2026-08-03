package com.medimanage.feature.radiology;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface RadiologyRepository extends JpaRepository<Radiology, Long> {
    List<Radiology> findAllByPatientId(Long patientId, Sort sort);
    List<Radiology> findAllByVisitId(Long visitId);
}
