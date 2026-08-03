package com.medimanage.feature.user.dto;

import com.medimanage.feature.user.User;
import com.medimanage.feature.user.UserRole;

import java.time.Instant;

public record UserDto(
        Long id,
        String email,
        String firstName,
        String lastName,
        String fullName,
        UserRole role,
        String avatarUrl,
        String phone,
        boolean isActive,
        Instant createdAt
) {
    public static UserDto from(User u) {
        return new UserDto(
                u.getId(), u.getEmail(),
                u.getFirstName(), u.getLastName(), u.fullName(),
                u.getRole(), u.getAvatarUrl(), u.getPhone(),
                u.isActive(), u.getCreatedAt()
        );
    }
}
