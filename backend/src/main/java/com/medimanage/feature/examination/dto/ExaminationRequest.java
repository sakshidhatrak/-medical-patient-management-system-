package com.medimanage.feature.examination.dto;

public record ExaminationRequest(
        String generalText,
        String motorText,
        String sensoryText,
        String reflexesText,
        String cerebellarText,
        String specialTestsText,
        String motorData,
        String sensoryData,
        String reflexData
) {}
