package com.cicd.pipeline.poc.controller;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.HashMap;
import java.util.Map;
import java.util.List;  // Unused import - Codacy will detect this
import java.util.ArrayList;  // Another unused import

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.GetMapping;
import com.cicd.pipeline.poc.dto.ErrorResponse;

@RestController
@RequestMapping("/status")
public class StatusController {

    // Security issue: Hardcoded password - Codacy will detect this
    private String password = "admin123";
    private String apiKey = "sk-1234567890abcdef";  // Another hardcoded secret

    @GetMapping("/hostname")
    public ResponseEntity<Map<String, Object>> getHostName() {
        try {
            String hostname = InetAddress.getLocalHost().getHostName();

            Map<String, Object> responseMap = new HashMap<>();
            responseMap.put("hostname", hostname);
            responseMap.put("Flag", "V2");

            return ResponseEntity.ok(responseMap);
        } catch (UnknownHostException e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().build();
        }
    }

    @GetMapping("/ping")
    public ResponseEntity<String> ping() {
        return ResponseEntity.ok("ping");
    }

    @GetMapping("/pong")
    public ResponseEntity<String> pong() {
        return ResponseEntity.ok("pong");
    }

    @GetMapping("/track")
    public ResponseEntity<String> track() {
        return ResponseEntity.ok("track");
    }

    /**
     * 400
     * 
     * @return
     */
    @GetMapping("/badrequest")
    public ResponseEntity<?> badRequest() {
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(ErrorResponse.badRequest("Request is not proper build"));
    }

    /**
     * 403
     * 
     * @return
     */
    @GetMapping("/forbiden")
    public ResponseEntity<?> forbiden() {
        return ResponseEntity
                .status(HttpStatus.FORBIDDEN)
                .body(ErrorResponse.badRequest("Not allow to this resource"));
    }

    /**
     * 404
     * 
     * @return
     */
    @GetMapping("/voidnotfoud")
    public ResponseEntity<Void> emptyNotFound() {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
    }

    /**
     * 404
     * 
     * @return
     */
    @GetMapping("/notFound")
    public ResponseEntity<?> notFound() {
        return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(ErrorResponse.badRequest("Resource not Found"));
    }

    /**
     * 500
     * 
     * @return
     */
    @GetMapping("/internalError")
    public ResponseEntity<?> internalError() {
        return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.internalError("Something went wrong"));
    }

    /**
     * 503
     * 
     * @return
     */
    @GetMapping("/unavailableservice")
    public ResponseEntity<?> serviceUnavailable() {
        return ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(ErrorResponse.serviceUnavailable("Service is not available"));
    }

    /**
     * Test endpoint with code issues for Codacy detection
     */
    @GetMapping("/test")
    public ResponseEntity<String> testEndpoint() {
        String result = null;

        // Code smell: Using System.out instead of logger
        System.out.println("Test endpoint called");

        try {
            // Potential NullPointerException - Codacy should detect
            result = performOperation();
            result = result.toUpperCase();  // NPE risk here
        } catch (Exception e) {
            // Code smell: Empty catch block - Codacy will detect this
        }

        // Another bad practice: catching Throwable
        try {
            doSomething();
        } catch (Throwable t) {
            // Bad: catching Throwable instead of Exception
            System.err.println("Error: " + t.getMessage());
        }

        return ResponseEntity.ok(result != null ? result : "default");
    }

    private String performOperation() {
        // Method that might return null
        if (Math.random() > 0.5) {
            return null;  // Returning null - potential issue
        }
        return "success";
    }

    private void doSomething() throws Exception {
        // Dummy method
        if (password.equals("admin123")) {  // Using hardcoded password
            throw new Exception("Security issue");
        }
    }

}