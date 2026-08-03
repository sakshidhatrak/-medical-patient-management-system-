package com.medimanage.feature.photo;

import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.patient.PatientRepository;
import com.medimanage.feature.photo.dto.PhotoDto;
import com.medimanage.feature.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PhotoService {

    private final PhotoRepository repo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;

    @Value("${app.upload-dir:./uploads}")
    private String uploadDir;

    public List<PhotoDto> listByPatient(Long patientId, String category) {
        return (category != null
                ? repo.findAllByPatientIdAndCategory(patientId, category)
                : repo.findAllByPatientId(patientId))
                .stream().map(PhotoDto::from).toList();
    }

    public List<PhotoDto> listByVisit(Long visitId) {
        return repo.findAllByVisitId(visitId).stream().map(PhotoDto::from).toList();
    }

    @Transactional
    public PhotoDto uploadFile(Long patientId, Long visitId, Long surgeryId,
                               MultipartFile file, String category,
                               String caption, Long actorId) throws IOException {

        var patient = patientRepo.findById(patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Patient", patientId));
        var actor = userRepo.findById(actorId).orElse(null);

        String ext = resolveExt(file.getOriginalFilename(), file.getContentType());
        String cat = category != null ? category : "visit";
        // Use a temporary filename until we get the saved ID
        String tempName = System.currentTimeMillis() + "." + ext;
        String relativePath = patientId + "/" + cat + "/" + tempName;

        // Save file to disk
        Path target = Paths.get(uploadDir, relativePath);
        Files.createDirectories(target.getParent());
        file.transferTo(target);

        Photo photo = Photo.builder()
                .patient(patient)
                .visitId(visitId)
                .surgeryId(surgeryId)
                .storagePath(relativePath)
                .category(cat)
                .caption(caption)
                .fileSize((int) file.getSize())
                .mimeType(file.getContentType())
                .isUploaded(true)
                .createdBy(actor)
                .build();

        Photo saved = repo.save(photo);
        // Rename file to use actual DB id
        String finalPath = patientId + "/" + cat + "/" + saved.getId() + "." + ext;
        Path finalTarget = Paths.get(uploadDir, finalPath);
        Files.move(target, finalTarget);
        saved.setStoragePath(finalPath);
        return PhotoDto.from(repo.save(saved));
    }

    @Transactional
    public void delete(Long id) {
        repo.findById(id).ifPresent(photo -> {
            // Delete file from disk
            try {
                Path file = Paths.get(uploadDir, photo.getStoragePath());
                Files.deleteIfExists(file);
            } catch (IOException ignored) {}
            repo.delete(photo);
        });
    }

    private String resolveExt(String filename, String contentType) {
        if (filename != null) {
            String lower = filename.toLowerCase();
            if (lower.endsWith(".png"))  return "png";
            if (lower.endsWith(".pdf"))  return "pdf";
            if (lower.endsWith(".docx")) return "docx";
            if (lower.endsWith(".doc"))  return "doc";
            if (lower.endsWith(".xlsx")) return "xlsx";
            if (lower.endsWith(".xls"))  return "xls";
        }
        if (contentType != null) {
            if (contentType.equals("image/png"))  return "png";
            if (contentType.equals("application/pdf")) return "pdf";
        }
        return "jpeg";
    }
}
