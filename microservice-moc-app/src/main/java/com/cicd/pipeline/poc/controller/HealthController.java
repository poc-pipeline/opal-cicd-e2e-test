package com.cicd.pipeline.poc.controller;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class HealthController {
    
   
    
    /**
     * <b>GET /api/info</b> - Información de la aplicación y vulnerabilidades intencionales.
     * <p>
     * Devuelve detalles de la aplicación, propósito y vulnerabilidades conocidas (para pruebas de seguridad).
     * <ul>
     *   <li><b>application</b>: Nombre de la app</li>
     *   <li><b>description</b>: Descripción</li>
     *   <li><b>vulnerabilities</b>: Vulnerabilidades clasificadas por criticidad</li>
     * </ul>
     * <p>
     * <b>Nota:</b> Las vulnerabilidades son intencionales para validar herramientas de CI/CD.
     * @return ResponseEntity 200 OK con información de la app
     */
    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info() {
        Map<String, Object> response = new HashMap<>();
        response.put("application", "CI/CD Pipeline PoC");
        response.put("description", "Mock application with intentional vulnerabilities for testing CI/CD pipeline gates");
        response.put("vulnerabilities", Map.of(
            "critical", "log4j 2.14.1 (CVE-2021-44228)",
            "high", "commons-collections 3.2.1 (CVE-2015-6420)",
            "medium", "jackson-databind 2.9.10.1"
        ));
        return ResponseEntity.ok(response);
    }
    
    /**
     * <b>GET /api/status</b> - Estado básico del servicio.
     * <p>
     * Devuelve un mensaje simple de disponibilidad. Útil para health checks ligeros en balanceadores o monitores.
     * <p>
     * <b>Ejemplo:</b> "Service is running smoothly."
     * @return ResponseEntity 200 OK con texto plano
     */
    @GetMapping("/status")
    public ResponseEntity<String> status() {
        return ResponseEntity.ok("Service is running smoothly.");
    }
    
    /**
     * <b>GET /api/health/status</b> - Estado de salud con fecha legible.
     * <p>
     * Devuelve un mensaje de texto plano con el estado y la fecha actual (DD/MM/YYYY).
     * Útil para auditoría, debugging y monitoreo manual.
     * <p>
     * <b>Ejemplo:</b> "Service is running smoothy. Date: 15/10/2025"
     * @return ResponseEntity 200 OK con texto plano
     */
    @GetMapping("/health/status")
    public ResponseEntity<String> healthStatus() {
        LocalDateTime now = LocalDateTime.now();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy");
        String formattedDate = now.format(formatter);
        String response = "Service is running smoothy. Date: " + formattedDate;
        return ResponseEntity.ok(response);
    }
    /**
     * <b>GET /api/time</b> - Devuelve la hora actual del servidor.
     * <p>
     * Respuesta en JSON con los campos:
     * <ul>
     *   <li><b>time</b>: Hora legible en formato HH:mm:ss</li>
     *   <li><b>timestamp</b>: Marca de tiempo ISO_LOCAL_DATE_TIME</li>
     *   <li><b>timezone</b>: Zona horaria del servidor (ID)</li>
     * </ul>
     * <p>
     * Útil para pruebas rápidas y sincronización horaria entre componentes.
     * @return ResponseEntity 200 OK con JSON que contiene la hora actual
     */
    @GetMapping("/time")
    public ResponseEntity<Map<String, Object>> time() {
        LocalDateTime now = LocalDateTime.now();
        String time = now.format(DateTimeFormatter.ofPattern("HH:mm:ss"));
        String timestamp = now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        Map<String, Object> response = new HashMap<>();
        response.put("time", time);
        response.put("timestamp", timestamp);
        response.put("timezone", java.time.ZoneId.systemDefault().toString());
        return ResponseEntity.ok(response);
    }
    
    /**
     * <b>GET /api/health</b> - Estado de salud del servicio.
     * <p>
     * Devuelve un JSON con el estado de salud del servicio.
     * <ul>
     *   <li><b>status</b>: "UP" si el servicio está operativo</li>
     * </ul>
     * <p>
     * <b>Ejemplo:</b> {"status": "UP"}
     * @return ResponseEntity 200 OK con JSON de estado
     */
   @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        // Use ISO_LOCAL_DATE_TIME string for predictable JSON representation
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        response.put("timestamp", timestamp);
        response.put("service", "cicd-pipeline-poc-app");
        response.put("version", "1.0.0");
        return ResponseEntity.ok(response);
    }
}
