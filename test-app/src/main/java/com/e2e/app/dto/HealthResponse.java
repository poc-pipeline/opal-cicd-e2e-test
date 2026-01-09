package com.e2e.app.dto;

public record HealthResponse(
        String status,
        String timestamp,
        String serviceName,
        String version
) {}
