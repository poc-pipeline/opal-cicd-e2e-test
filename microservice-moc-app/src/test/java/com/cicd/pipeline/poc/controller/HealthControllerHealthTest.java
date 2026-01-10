package com.cicd.pipeline.poc.controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class HealthControllerHealthTest {

    private HealthController healthController;

    @BeforeEach
    void setUp() {
        healthController = new HealthController();
    }

    @Test
    void healthEndpoint_ShouldReturnUpStatusAndIsoTimestamp() {
        ResponseEntity<Map<String, Object>> response = healthController.health();

        assertEquals(200, response.getStatusCodeValue());
        Map<String, Object> body = response.getBody();
        assertNotNull(body);

        assertEquals("UP", body.get("status"));
        assertTrue(body.containsKey("timestamp"));
        assertTrue(body.containsKey("service"));
        assertTrue(body.containsKey("version"));

        Object tsObj = body.get("timestamp");
        assertNotNull(tsObj);
        assertTrue(tsObj instanceof String);

        String ts = (String) tsObj;
        // Basic ISO_LOCAL_DATE_TIME pattern check: YYYY-...T..:..:..
        assertTrue(ts.matches("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}.*"));
    }
}