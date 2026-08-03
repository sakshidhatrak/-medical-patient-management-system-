package com.medimanage.feature.template;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PrintTemplateRepository extends JpaRepository<PrintTemplate, Long> {
    Optional<PrintTemplate> findByIsDefaultTrue();
}
