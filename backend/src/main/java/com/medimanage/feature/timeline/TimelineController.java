package com.medimanage.feature.timeline;

import com.medimanage.common.ApiResponse;
import com.medimanage.feature.timeline.dto.TimelineEventDto;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/patients/{patientId}/timeline")
@RequiredArgsConstructor
public class TimelineController {

    private final TimelineRepository repo;

    @GetMapping
    public ResponseEntity<ApiResponse<List<TimelineEventDto>>> list(@PathVariable Long patientId) {
        List<TimelineEventDto> events = repo
                .findAllByPatientId(patientId, Sort.by("eventDate").descending())
                .stream().map(TimelineEventDto::from).toList();
        return ResponseEntity.ok(ApiResponse.ok(events));
    }
}
