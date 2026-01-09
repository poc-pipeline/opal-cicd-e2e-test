package com.e2e.app.controller;

import com.e2e.app.dto.HealthResponse;
import com.e2e.app.dto.InfoResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

class AppControllerTest {

    private AppController controller;

    @BeforeEach
    void setUp() {
        controller = new AppController();
        ReflectionTestUtils.setField(controller, "applicationName", "test-app");
        ReflectionTestUtils.setField(controller, "appVersion", "1.0.0");
    }

    @Test
    void hello_ShouldReturnGreeting() {
        ResponseEntity<String> response = controller.hello();

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertTrue(response.getBody().contains("Hello"));
    }

    @Test
    void status_ShouldReturnRunningStatus() {
        ResponseEntity<String> response = controller.status();

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertTrue(response.getBody().contains("running smoothly"));
    }

    @Test
    void status_ShouldIncludeTimestamp() {
        ResponseEntity<String> response = controller.status();

        assertNotNull(response.getBody());
        assertTrue(response.getBody().contains("Timestamp"));
    }

    @Test
    void health_ShouldReturnUpStatus() {
        ResponseEntity<HealthResponse> response = controller.health();

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("UP", response.getBody().status());
    }

    @Test
    void health_ShouldIncludeServiceName() {
        ResponseEntity<HealthResponse> response = controller.health();

        assertNotNull(response.getBody());
        assertEquals("test-app", response.getBody().serviceName());
    }

    @Test
    void health_ShouldIncludeVersion() {
        ResponseEntity<HealthResponse> response = controller.health();

        assertNotNull(response.getBody());
        assertEquals("1.0.0", response.getBody().version());
    }

    @Test
    void health_ShouldIncludeTimestamp() {
        ResponseEntity<HealthResponse> response = controller.health();

        assertNotNull(response.getBody());
        assertNotNull(response.getBody().timestamp());
        assertFalse(response.getBody().timestamp().isEmpty());
    }

    @Test
    void info_ShouldReturnAppInfo() {
        ResponseEntity<InfoResponse> response = controller.info();

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
    }

    @Test
    void info_ShouldIncludeCorrectName() {
        ResponseEntity<InfoResponse> response = controller.info();

        assertNotNull(response.getBody());
        assertEquals("test-app", response.getBody().name());
    }

    @Test
    void info_ShouldIncludeDescription() {
        ResponseEntity<InfoResponse> response = controller.info();

        assertNotNull(response.getBody());
        assertNotNull(response.getBody().description());
        assertFalse(response.getBody().description().isEmpty());
    }

    @Test
    void info_ShouldIncludeFramework() {
        ResponseEntity<InfoResponse> response = controller.info();

        assertNotNull(response.getBody());
        assertTrue(response.getBody().framework().contains("Spring Boot"));
    }

    @Test
    void info_ShouldIncludeJavaVersion() {
        ResponseEntity<InfoResponse> response = controller.info();

        assertNotNull(response.getBody());
        assertTrue(response.getBody().javaVersion().contains("Java"));
    }
}
