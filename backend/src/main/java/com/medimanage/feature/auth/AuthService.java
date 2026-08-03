package com.medimanage.feature.auth;

import com.medimanage.common.exception.BadRequestException;
import com.medimanage.common.exception.ResourceNotFoundException;
import com.medimanage.feature.auth.dto.AuthResponse;
import com.medimanage.feature.auth.dto.LoginRequest;
import com.medimanage.feature.auth.dto.RegisterRequest;
import com.medimanage.feature.user.User;
import com.medimanage.feature.user.UserRepository;
import com.medimanage.feature.user.UserRole;
import com.medimanage.feature.user.dto.UserDto;
import com.medimanage.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtProvider;

    public AuthResponse login(LoginRequest req) {
        User user = userRepo.findByEmail(req.email())
                .orElseThrow(() -> new BadRequestException("Invalid email or password"));

        if (!user.isActive()) {
            throw new BadRequestException("Account is deactivated. Contact admin.");
        }

        if (!passwordEncoder.matches(req.password(), user.getPassword())) {
            throw new BadRequestException("Invalid email or password");
        }

        String token = jwtProvider.generateToken(
                user.getId(), user.getEmail(), user.getRole().name());
        return new AuthResponse(token, UserDto.from(user));
    }

    @Transactional
    public AuthResponse register(RegisterRequest req) {
        if (userRepo.existsByEmail(req.email())) {
            throw new BadRequestException("Email already registered");
        }

        User user = User.builder()
                .email(req.email())
                .password(passwordEncoder.encode(req.password()))
                .firstName(req.firstName())
                .lastName(req.lastName() != null ? req.lastName() : "")
                .role(req.role() != null ? req.role() : UserRole.assistant)
                .isActive(true)
                .build();

        user = userRepo.save(user);
        String token = jwtProvider.generateToken(
                user.getId(), user.getEmail(), user.getRole().name());
        return new AuthResponse(token, UserDto.from(user));
    }
}
