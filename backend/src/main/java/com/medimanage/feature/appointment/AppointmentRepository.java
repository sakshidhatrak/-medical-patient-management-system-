package com.medimanage.feature.appointment;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface AppointmentRepository extends JpaRepository<Appointment, Long> {
    List<Appointment> findAllByPatientIdAndIsActiveTrue(Long patientId, Sort sort);
    Optional<Appointment> findByIdAndIsActiveTrue(Long id);

    @Query("SELECT a FROM Appointment a WHERE a.isActive = true AND a.scheduledAt BETWEEN :from AND :to ORDER BY a.scheduledAt ASC")
    List<Appointment> findByDateRange(@Param("from") Instant from, @Param("to") Instant to);
}
