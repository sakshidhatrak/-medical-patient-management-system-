package com.medimanage.feature.vitals;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VitalsRepository extends JpaRepository<Vitals, Long> {
    List<Vitals> findAllByPatientIdAndIsActiveTrue(Long patientId, Sort sort);
    List<Vitals> findAllByVisitIdAndIsActiveTrue(Long visitId);
}
