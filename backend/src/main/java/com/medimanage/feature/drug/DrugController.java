package com.medimanage.feature.drug;

import com.medimanage.common.ApiResponse;
import com.medimanage.feature.drug.dto.DrugDto;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/drugs")
@RequiredArgsConstructor
public class DrugController {

    private final DrugRepository repo;

    @GetMapping
    public ResponseEntity<ApiResponse<List<DrugDto>>> list(
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "30") int limit) {
        List<DrugDto> result = (search != null && !search.isBlank())
                ? repo.search(search, PageRequest.of(0, limit)).stream().map(DrugDto::from).toList()
                : repo.findAllByIsActiveTrueOrderByGenericName().stream().map(DrugDto::from).toList();
        return ResponseEntity.ok(ApiResponse.ok(result));
    }
}
