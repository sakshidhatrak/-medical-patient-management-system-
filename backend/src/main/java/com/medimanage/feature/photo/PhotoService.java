package com.medimanage.feature.photo;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.patient.PatientRepository;
import com.medimanage.feature.photo.dto.PhotoDto;
import com.medimanage.feature.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class PhotoService {

    private final PhotoRepository repo;
    private final PatientRepository patientRepo;
    private final UserRepository userRepo;
    private final Cloudinary cloudinary;

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

        String cat = category != null ? category : "visit";
        String folder = "medimanage/" + patientId + "/" + cat;

        @SuppressWarnings("unchecked")
        Map<String, Object> result = (Map<String, Object>) cloudinary.uploader().upload(
                file.getBytes(),
                ObjectUtils.asMap("folder", folder, "resource_type", "auto")
        );

        String publicId  = (String) result.get("public_id");
        String secureUrl = (String) result.get("secure_url");

        Photo photo = Photo.builder()
                .patient(patient)
                .visitId(visitId)
                .surgeryId(surgeryId)
                .storagePath(publicId)
                .cloudinaryUrl(secureUrl)
                .category(cat)
                .caption(caption)
                .fileSize((int) file.getSize())
                .mimeType(file.getContentType())
                .isUploaded(true)
                .createdBy(actor)
                .build();

        return PhotoDto.from(repo.save(photo));
    }

    @Transactional
    public void delete(Long id) {
        repo.findById(id).ifPresent(photo -> {
            try {
                cloudinary.uploader().destroy(
                        photo.getStoragePath(),
                        ObjectUtils.asMap("resource_type", "auto")
                );
            } catch (IOException ignored) {}
            repo.delete(photo);
        });
    }
}
