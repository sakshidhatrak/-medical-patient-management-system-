package com.medimanage.feature.drug;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface DrugRepository extends JpaRepository<Drug, Long> {

    @Query("""
        SELECT d FROM Drug d
        WHERE d.isActive = true
        AND (LOWER(d.genericName) LIKE LOWER(CONCAT('%',:q,'%'))
          OR LOWER(d.brandNames)  LIKE LOWER(CONCAT('%',:q,'%')))
        ORDER BY d.genericName
        """)
    List<Drug> search(@Param("q") String query, Pageable pageable);

    List<Drug> findAllByIsActiveTrueOrderByGenericName();
}
