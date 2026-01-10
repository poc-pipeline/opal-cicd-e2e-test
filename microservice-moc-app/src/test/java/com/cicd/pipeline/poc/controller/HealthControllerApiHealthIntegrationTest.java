package com.cicd.pipeline.poc.controller;

import org.junit.jupiter.api.BeforeEach;
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
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;

/**
 * Integration test for GET /api/health endpoint.
 */
@SpringBootTest
@AutoConfigureWebMvc
@TestPropertySource(properties = {
    "server.port=0",
    "spring.main.lazy-initialization=true"
})
class HealthControllerApiHealthIntegrationTest {

    @Autowired
    private WebApplicationContext webApplicationContext;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext).build();
    }

    @Test
    void getApiHealth_ShouldReturnStatusUpJson() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void getApiInfo_ShouldReturnApplicationInfoJson() throws Exception {
        mockMvc.perform(get("/api/info"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.application").value("CI/CD Pipeline PoC"))
                .andExpect(jsonPath("$.description").isNotEmpty())
                .andExpect(jsonPath("$.vulnerabilities.critical").isNotEmpty())
                .andExpect(jsonPath("$.vulnerabilities.high").isNotEmpty())
                .andExpect(jsonPath("$.vulnerabilities.medium").isNotEmpty());
    }
}
