package com.cicd.pipeline.poc.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureWebMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Integration tests for HealthController using MockMvc
 */
@SpringBootTest
@AutoConfigureWebMvc
@TestPropertySource(properties = {
    "server.port=0",  // Use random port for testing
    "spring.main.lazy-initialization=true"  // Speed up test execution
})
class HealthControllerIntegrationTest {

    @Autowired
    private WebApplicationContext webApplicationContext;

    private MockMvc mockMvc;

    @org.junit.jupiter.api.BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext).build();
    }

    @Test
    void testHealthStatusEndpoint_ShouldReturnOk() throws Exception {
        mockMvc.perform(get("/api/health/status"))
                .andExpect(status().isOk())
                //.andExpect(content().contentType(MediaType.TEXT_PLAIN))
                .andExpect(content().string(org.hamcrest.Matchers.startsWith("Service is running smoothy. Date: ")));
    }

    @Test
    void testHealthStatusEndpoint_ShouldReturnCorrectDateFormat() throws Exception {
        mockMvc.perform(get("/api/health/status"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.matchesRegex(
                    "Service is running smoothy\\. Date: \\d{2}/\\d{2}/\\d{4}")));
    }

    @Test
    void testHealthStatusEndpoint_ShouldReturnTodayDate() throws Exception {
        String expectedDate = java.time.LocalDateTime.now()
                .format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy"));
        String expectedContent = "Service is running smoothy. Date: " + expectedDate;

        mockMvc.perform(get("/api/health/status"))
                .andExpect(status().isOk())
                .andExpect(content().string(expectedContent));
    }

    @Test
    void testHealthStatusEndpoint_ShouldNotBeEmpty() throws Exception {
        mockMvc.perform(get("/api/health/status"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.not(org.hamcrest.Matchers.emptyString())))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Service is running smoothy")));
    }
}