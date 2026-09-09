package com.medimanage.config;

import com.medimanage.feature.user.User;
import com.medimanage.feature.user.UserRepository;
import com.medimanage.feature.user.UserRole;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        repairRoleConstraint();
        seedUser("admin@medimanage.com", "Admin",  "User",  UserRole.admin, "Admin@123");
        seedUser("admin@test.com",       "Admin",  "User",  UserRole.admin, "Admin@123");
        seedUser("staff@medimanage.com", "Staff",  "User",  UserRole.staff, "Staff@123");
    }

    /**
     * Drops and recreates the role check constraint so new enum values are accepted.
     * Needed when ddl-auto=update doesn't alter existing constraints.
     */
    private void repairRoleConstraint() {
        try {
            jdbcTemplate.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check");
            jdbcTemplate.execute(
                "ALTER TABLE users ADD CONSTRAINT users_role_check " +
                "CHECK (role IN ('admin','staff','assistant','doctor','nurse','receptionist'))"
            );
            log.info("Role constraint repaired");
        } catch (Exception e) {
            log.warn("Could not repair role constraint: {}", e.getMessage());
        }
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
