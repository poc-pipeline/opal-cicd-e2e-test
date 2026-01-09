package com.e2e.app.controller;

import com.e2e.app.dto.HealthResponse;
import com.e2e.app.dto.InfoResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@RestController
@RequestMapping("/api")
public class AppController {

    @Value("${spring.application.name:opal-e2e-test-app}")
    private String applicationName;

    @Value("${app.version:1.0.0}")
    private String appVersion;

    @GetMapping("/hello")
    public ResponseEntity<String> hello() {
        return ResponseEntity.ok("Hello from OPAL E2E Test Application!");
    }

    @GetMapping("/status")
    public ResponseEntity<String> status() {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss"));
        return ResponseEntity.ok("Service is running smoothly. Timestamp: " + timestamp);
    }

    @GetMapping("/health")
    public ResponseEntity<HealthResponse> health() {
        return ResponseEntity.ok(new HealthResponse(
                "UP",
                LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                applicationName,
                appVersion
        ));
    }

    @GetMapping("/info")
    public ResponseEntity<InfoResponse> info() {
        return ResponseEntity.ok(new InfoResponse(
                applicationName,
                "Test application for OPAL CI/CD pipeline end-to-end testing",
                appVersion,
                "Spring Boot 3.1.5",
                "Java 17"
        ));
    }
}
