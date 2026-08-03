package com.medimanage.feature.timeline.dto;

import com.medimanage.feature.timeline.TimelineEvent;

import java.time.Instant;

public record TimelineEventDto(
        Long id, Long patientId,
        String eventType, Long referenceId,
        Instant eventDate, String summary,
        Instant createdAt
) {
    public static TimelineEventDto from(TimelineEvent e) {
        return new TimelineEventDto(
                e.getId(), e.getPatient().getId(),
                e.getEventType(), e.getReferenceId(),
                e.getEventDate(), e.getSummary(), e.getCreatedAt()
        );
    }
}
