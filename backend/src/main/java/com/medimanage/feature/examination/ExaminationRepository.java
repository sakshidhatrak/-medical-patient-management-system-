package com.medimanage.feature.examination;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface ExaminationRepository extends JpaRepository<Examination, Long> {
    Optional<Examination> findByVisitId(Long visitId);
}
