package com.medimanage.feature.photo.dto;

import com.medimanage.feature.photo.Photo;

import java.time.Instant;

public record PhotoDto(
        Long id,
        Long patientId,
        Long visitId,
        Long surgeryId,
        String storagePath,
        String viewUrl,        // derived: /api/photos/file/{storagePath}
        String category,
        String caption,
        Integer fileSize,
        String mimeType,
        boolean isUploaded,
        Instant createdAt
) {
    public static PhotoDto from(Photo p) {
        return new PhotoDto(
                p.getId(),
                p.getPatient().getId(),
                p.getVisitId(),
                p.getSurgeryId(),
                p.getStoragePath(),
                "/api/photos/file/" + p.getStoragePath(),  // derived at query time
                p.getCategory(),
                p.getCaption(),
                p.getFileSize(),
                p.getMimeType(),
                p.isUploaded(),
                p.getCreatedAt()
        );
    }
}
