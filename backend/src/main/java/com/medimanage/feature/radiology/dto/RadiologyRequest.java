package com.medimanage.feature.radiology.dto;

public record RadiologyRequest(Long visitId, Long surgeryId, String text, String investigations) {}
