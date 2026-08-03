package com.medimanage.feature.template.dto;

import com.medimanage.feature.template.PrintTemplate;
import com.medimanage.feature.template.PrintTemplateField;

import java.time.Instant;
import java.util.List;

public record PrintTemplateDto(
        Long id, String name, boolean isDefault,
        List<FieldDto> fields,
        Instant createdAt, Instant updatedAt
) {
    public record FieldDto(
            Long id, String fieldKey, String fieldLabel,
            String section, boolean isEnabled, int displayOrder
    ) {
        static FieldDto from(PrintTemplateField f) {
            return new FieldDto(f.getId(), f.getFieldKey(), f.getFieldLabel(),
                    f.getSection(), f.isEnabled(), f.getDisplayOrder());
        }
    }

    public static PrintTemplateDto from(PrintTemplate t) {
        return new PrintTemplateDto(
                t.getId(), t.getName(), t.isDefault(),
                t.getFields().stream().map(FieldDto::from).toList(),
                t.getCreatedAt(), t.getUpdatedAt()
        );
    }
}
