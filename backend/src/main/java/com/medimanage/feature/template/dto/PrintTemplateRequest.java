package com.medimanage.feature.template.dto;

import java.util.List;

public record PrintTemplateRequest(
        String name,
        boolean isDefault,
        List<FieldItem> fields
) {
    public record FieldItem(
            String fieldKey,
            String fieldLabel,
            String section,
            boolean isEnabled,
            int displayOrder
    ) {}
}
