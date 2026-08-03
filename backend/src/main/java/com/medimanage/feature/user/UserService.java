package com.medimanage.feature.user;

import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.user.dto.UserDto;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository repo;

    public List<UserDto> listAll() {
        return repo.findAll().stream().map(UserDto::from).toList();
    }

    public UserDto getById(Long id) {
        return UserDto.from(findOrThrow(id));
    }

    public UserDto getByEmail(String email) {
        return repo.findByEmail(email)
                .map(UserDto::from)
                .orElseThrow(() -> new ResourceNotFoundException("User", email));
    }

    @Transactional
    public UserDto updateProfile(Long id, String firstName, String lastName,
                                 String phone, String avatarUrl) {
        User u = findOrThrow(id);
        if (firstName  != null) u.setFirstName(firstName);
        if (lastName   != null) u.setLastName(lastName);
        if (phone      != null) u.setPhone(phone);
        if (avatarUrl  != null) u.setAvatarUrl(avatarUrl);
        return UserDto.from(repo.save(u));
    }

    @Transactional
    public void deactivate(Long id) {
        User u = findOrThrow(id);
        u.setActive(false);
        repo.save(u);
    }

    private User findOrThrow(Long id) {
        return repo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
    }
}
