package com.medimanage.feature.template;

import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.template.dto.PrintTemplateDto;
import com.medimanage.feature.template.dto.PrintTemplateRequest;
import com.medimanage.feature.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class PrintTemplateService {

    private final PrintTemplateRepository repo;
    private final UserRepository userRepo;

    public List<PrintTemplateDto> listAll() {
        return repo.findAll().stream().map(PrintTemplateDto::from).toList();
    }

    public PrintTemplateDto getById(Long id) {
        return PrintTemplateDto.from(findOrThrow(id));
    }

    @Transactional
    public PrintTemplateDto create(PrintTemplateRequest req, Long actorId) {
        var actor = userRepo.findById(actorId).orElse(null);
        PrintTemplate t = PrintTemplate.builder()
                .name(req.name())
                .isDefault(req.isDefault())
                .createdBy(actor)
                .build();

        if (req.fields() != null) {
            req.fields().forEach(f -> t.getFields().add(
                    PrintTemplateField.builder()
                            .template(t)
                            .fieldKey(f.fieldKey())
                            .fieldLabel(f.fieldLabel())
                            .section(f.section())
                            .isEnabled(f.isEnabled())
                            .displayOrder(f.displayOrder())
                            .build()
            ));
        }
        return PrintTemplateDto.from(repo.save(t));
    }

    @Transactional
    public PrintTemplateDto update(Long id, PrintTemplateRequest req, Long actorId) {
        PrintTemplate t = findOrThrow(id);
        if (req.name() != null) t.setName(req.name());
        t.setDefault(req.isDefault());
        if (req.fields() != null) {
            t.getFields().clear();
            req.fields().forEach(f -> t.getFields().add(
                    PrintTemplateField.builder()
                            .template(t)
                            .fieldKey(f.fieldKey())
                            .fieldLabel(f.fieldLabel())
                            .section(f.section())
                            .isEnabled(f.isEnabled())
                            .displayOrder(f.displayOrder())
                            .build()
            ));
        }
        return PrintTemplateDto.from(repo.save(t));
    }

    @Transactional
    public void delete(Long id) {
        repo.deleteById(id);
    }

    private PrintTemplate findOrThrow(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("PrintTemplate", id));
    }
}
