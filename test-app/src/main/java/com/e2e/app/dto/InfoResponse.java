package com.e2e.app.dto;

public record InfoResponse(
        String name,
        String description,
        String version,
        String framework,
        String javaVersion
) {}
