package com.medimanage.feature.visit;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface VisitRepository extends JpaRepository<Visit, Long> {
    List<Visit> findAllByPatientIdAndIsActiveTrue(Long patientId, Sort sort);
    Optional<Visit> findByIdAndPatientIdAndIsActiveTrue(Long id, Long patientId);
    Optional<Visit> findByClientIdAndPatientId(String clientId, Long patientId);

    long countByPatientIdAndIsActiveTrue(Long patientId);
}
