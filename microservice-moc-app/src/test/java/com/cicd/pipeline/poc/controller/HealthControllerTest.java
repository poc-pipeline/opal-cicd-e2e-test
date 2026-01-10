package com.cicd.pipeline.poc.controller;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for HealthController
 */
class HealthControllerTest {

    private HealthController healthController;

    @BeforeEach
    void setUp() {
        healthController = new HealthController();
    }

    @Test
    void testHealthStatus_ShouldReturnOkStatus() {
        // Act
        ResponseEntity<String> response = healthController.healthStatus();

        // Assert
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
    }

    @Test
    void testHealthStatus_ShouldReturnCorrectMessageFormat() {
        // Act
        ResponseEntity<String> response = healthController.healthStatus();
        String responseBody = response.getBody();

        // Assert
        assertNotNull(responseBody);
        assertTrue(responseBody.startsWith("Service is running smoothy. Date: "));
    }

    @Test
    void testHealthStatus_ShouldReturnCurrentDateInCorrectFormat() {
        // Act
        ResponseEntity<String> response = healthController.healthStatus();
        String responseBody = response.getBody();

        // Assert
        assertNotNull(responseBody);

        // Extract date from response
        String datePart = responseBody.substring("Service is running smoothy. Date: ".length());

        // Verify date format is DD/MM/YYYY
        DateTimeFormatter expectedFormatter = DateTimeFormatter.ofPattern("dd/MM/yyyy");
        LocalDateTime parsedDate = LocalDateTime.parse(datePart + " 00:00:00", 
            DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss"));

        // Verify it's a valid date (not null means parsing was successful)
        assertNotNull(parsedDate);

        // Verify the format matches exactly DD/MM/YYYY
        assertTrue(datePart.matches("\\d{2}/\\d{2}/\\d{4}"));
    }

    @Test
    void testHealthStatus_ShouldReturnTodayDate() {
        // Arrange
        String expectedDate = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
        String expectedMessage = "Service is running smoothy. Date: " + expectedDate;

        // Act
        ResponseEntity<String> response = healthController.healthStatus();
        String responseBody = response.getBody();

        // Assert
        assertEquals(expectedMessage, responseBody);
    }

    @Test
    void testHealthStatus_ResponseBodyShouldNotBeEmpty() {
        // Act
        ResponseEntity<String> response = healthController.healthStatus();

        // Assert
        assertNotNull(response.getBody());
        assertFalse(response.getBody().isEmpty());
        assertTrue(response.getBody().length() > 30); // Minimum expected length
    }

    @Test
    void testHealthStatus_ShouldContainExpectedKeywords() {
        // Act
        ResponseEntity<String> response = healthController.healthStatus();
        String responseBody = response.getBody();

        // Assert
        assertTrue(responseBody.contains("Service is running smoothy"));
        assertTrue(responseBody.contains("Date:"));
        assertTrue(responseBody.contains("/")); // Date separator
    }
}
