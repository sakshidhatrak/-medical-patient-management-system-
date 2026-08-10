package com.medimanage.feature.patient;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PatientRepository extends JpaRepository<Patient, Long> {

    Page<Patient> findAllByIsActiveTrue(Pageable pageable);

    @Query("""
        SELECT p FROM Patient p
        WHERE p.isActive = true
        AND (LOWER(p.firstName) LIKE LOWER(CONCAT('%',:q,'%'))
          OR LOWER(p.lastName)  LIKE LOWER(CONCAT('%',:q,'%'))
          OR p.prn   LIKE CONCAT('%',:q,'%')
          OR p.phone LIKE CONCAT('%',:q,'%'))
        """)
    Page<Patient> search(@Param("q") String query, Pageable pageable);

    @Query("""
        SELECT p FROM Patient p
        WHERE p.isActive = true
        AND LOWER(p.firstName) LIKE LOWER(CONCAT('%',:name,'%'))
        """)
    List<Patient> findDuplicatesByName(@Param("name") String name, Pageable pageable);

    Optional<Patient> findByIdAndIsActiveTrue(Long id);

    long countByPrnStartingWith(String prefix);
}
