package com.medimanage.feature.photo;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PhotoRepository extends JpaRepository<Photo, Long> {
    List<Photo> findAllByPatientId(Long patientId);
    List<Photo> findAllByPatientIdAndCategory(Long patientId, String category);
    List<Photo> findAllByVisitId(Long visitId);
    List<Photo> findAllBySurgeryId(Long surgeryId);
}
