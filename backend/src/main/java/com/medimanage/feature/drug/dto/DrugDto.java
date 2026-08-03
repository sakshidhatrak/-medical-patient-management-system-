package com.medimanage.feature.drug.dto;

import com.medimanage.feature.drug.Drug;

public record DrugDto(
        Long id, String genericName, String brandNames,
        String composition, String category,
        String defaultDose, String defaultFrequency, String defaultDuration
) {
    public static DrugDto from(Drug d) {
        return new DrugDto(d.getId(), d.getGenericName(), d.getBrandNames(),
                d.getComposition(), d.getCategory(),
                d.getDefaultDose(), d.getDefaultFrequency(), d.getDefaultDuration());
    }
}
