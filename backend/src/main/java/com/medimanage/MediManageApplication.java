package com.medimanage;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@SpringBootApplication
@EnableJpaAuditing
public class MediManageApplication {
    public static void main(String[] args) {
        SpringApplication.run(MediManageApplication.class, args);
    }
}
