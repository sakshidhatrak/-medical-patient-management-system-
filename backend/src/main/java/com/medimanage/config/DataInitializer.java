package com.medimanage.config;

import com.medimanage.feature.user.User;
import com.medimanage.feature.user.UserRepository;
import com.medimanage.feature.user.UserRole;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        seedAdmin("admin@medimanage.com", "Admin", "User");
        seedAdmin("admin@test.com", "Admin", "User");
    }

    private void seedAdmin(String email, String firstName, String lastName) {
        if (!userRepo.existsByEmail(email)) {
            userRepo.save(User.builder()
                    .email(email)
                    .password(passwordEncoder.encode("Admin@123"))
                    .firstName(firstName)
                    .lastName(lastName)
                    .role(UserRole.admin)
                    .isActive(true)
                    .build());
            log.info("Seeded admin user: {}", email);
        }
    }
}
