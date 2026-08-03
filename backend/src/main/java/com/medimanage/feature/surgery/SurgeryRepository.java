package com.medimanage.feature.surgery;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SurgeryRepository extends JpaRepository<Surgery, Long> {
    List<Surgery> findAllByPatientIdAndIsActiveTrue(Long patientId, Sort sort);
    Optional<Surgery> findByIdAndPatientIdAndIsActiveTrue(Long id, Long patientId);
}
