package com.medimanage.feature.timeline;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TimelineRepository extends JpaRepository<TimelineEvent, Long> {
    List<TimelineEvent> findAllByPatientId(Long patientId, Sort sort);
}
