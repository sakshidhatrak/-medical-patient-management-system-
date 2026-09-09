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
        seedUser("admin@medimanage.com", "Admin",  "User",  UserRole.admin, "Admin@123");
        seedUser("admin@test.com",       "Admin",  "User",  UserRole.admin, "Admin@123");
        seedUser("staff@medimanage.com", "Staff",  "User",  UserRole.staff, "Staff@123");
    }

    private void seedUser(String email, String firstName, String lastName,
                          UserRole role, String rawPassword) {
        if (!userRepo.existsByEmail(email)) {
            userRepo.save(User.builder()
                    .email(email)
                    .password(passwordEncoder.encode(rawPassword))
                    .firstName(firstName)
                    .lastName(lastName)
                    .role(role)
                    .isActive(true)
                    .build());
            log.info("Seeded {} user: {}", role, email);
        }
    }
}
