# Información Complementaria CSMQ - SonarQube Cloud

Aquí tienes el borrador del correo redactado específicamente para cubrir los puntos solicitados por Colin durante la sesión, estructurado para que pueda copiar y pegar la información directamente en el registro del CSMQ.

---

**Asunto:** Información Complementaria CSMQ: Mecanismos de Autenticación y Flujo Paso a Paso - Integración SonarQube Cloud/GitHub

Estimado Colin,

En seguimiento a nuestra sesión y para dar cierre a los puntos requeridos para el registro en el CSMQ, te comparto la información detallada sobre los métodos de autenticación y el flujo paso a paso del ciclo de vida de las credenciales para la integración de SonarQube Cloud.

A continuación, describimos los dos mecanismos soportados y el flujo unificado de integración.

---

## 1. Métodos de Autenticación y Privilegios

La arquitectura de seguridad de SonarQube Cloud para integración CI/CD se basa en los siguientes pilares:

**Identidad y Acceso (IAM):** La generación de Scoped Organization Tokens (SOTs) está restringida exclusivamente al rol de **Administrador de Organización**. Un usuario estándar o desarrollador no tiene privilegios para crear o gestionar estos tokens.

**Origen de la Identidad:** El inicio de sesión del Administrador para realizar cualquier configuración se realiza obligatoriamente a través del **SSO de Citi (SAML)**, asegurando que la identidad proviene de una fuente federada y confiable.

Existen dos mecanismos para autenticar la integración:

### Scoped Organization Tokens - SOTs (Opción A - Recomendada):

- **Mecanismo de Autenticación:** Se basa en tokens Bearer a nivel de organización.
- **Prefijo Identificador:** `sqco_` (permite identificación y auditoría).
- **Naturaleza:** Es un secreto bearer **opaco de alta entropía** (NO es JWT/JWE/JWS). Los tokens no contienen claims visibles al cliente y no son auto-descriptivos.
- **Permisos:** Scope limitado a "Execute Analysis" (principio de mínimo privilegio).
- **Rotación:** Programática (revocación vía UI + generación de nuevo token).
- **Expiración:** Configurable (90-180 días recomendado) o sin expiración.
- **Limpieza Automática:** Tokens inactivos por 60 días son eliminados automáticamente.
- **Disponibilidad:** Planes Team y Enterprise.

### Personal Access Tokens - PATs (Opción B - Legacy):

- **Mecanismo de Autenticación:** Se basa en tokens Bearer a nivel de usuario.
- **Naturaleza:** Es un secreto bearer **opaco de alta entropía** (NO es JWT/JWE/JWS).
- **Permisos:** Hereda TODOS los permisos del usuario (sobre-privilegio).
- **Rotación:** Programática (vía API `user_tokens/generate` y `user_tokens/revoke`).
- **Expiración:** Configurable.
- **Limpieza Automática:** Tokens inactivos por 60 días son eliminados automáticamente.
- **Disponibilidad:** Todos los planes (incluyendo Free).
- **Nota:** NO recomendado para nuevas implementaciones Enterprise.

---

## 2. Clarificación Importante: JWT/JWE/JWS (Respuesta Oficial SonarSource)

> Las APIs de SonarQube Cloud **NO** utilizan JWT, JWE o JWS para autenticación de clientes. Los tokens de API son secretos bearer opacos de alta entropía generados y almacenados por SonarQube Cloud; no contienen claims visibles al cliente y no son auto-descriptivos. Las longitudes de componentes JWE y JWS **NO son aplicables** al mecanismo de autenticación de API de SonarQube Cloud.

**Donde SÍ se usan JWTs:**
- Internamente en flujos SSO y login de plataformas DevOps (Auth0, GitHub, Azure DevOps).
- Algoritmos y tamaños de clave siguen configuración del IdP/Auth0.
- Estos tokens **NO** se exponen como tokens bearer de API.

---

## 3. Flujo de Integración y Ciclo de Vida (Paso a Paso)

A continuación, se detalla el ciclo de vida completo de la autenticación, desde el inicio de sesión del administrador hasta el cierre de la conexión:

1. **Inicio de Sesión Administrativo:** El usuario con rol de Administrador accede a la plataforma de SonarQube Cloud (sonarcloud.io) autenticándose mediante **Citi SSO (Single Sign-On)** usando SAML.

2. **Validación de Roles:** La plataforma valida que el usuario posea el rol de Organization Admin. Si no cuenta con este rol, no se habilita el acceso a la configuración de "Scoped Organization Tokens".

3. **Creación de Token de Organización (SOT):** El administrador navega a **Administration → Security → Scoped Organization Tokens** y crea un nuevo token específico para el pipeline de CI/CD, configurando:
   - Nombre descriptivo (e.g., `github-actions-ci`)
   - Fecha de expiración (recomendado: 90-180 días)
   - Scope de proyectos (todos o específicos)
   - Permisos (Execute Analysis)

4. **Generación de Credencial:** SonarQube Cloud genera un token opaco de alta entropía con prefijo `sqco_`. El token se muestra **una única vez** y debe copiarse inmediatamente.

5. **Almacenamiento Seguro:** El administrador copia el token generado y lo almacena inmediatamente en **GitHub Secrets** a nivel de organización o repositorio como `SONAR_TOKEN`. SonarQube Cloud no vuelve a mostrar el token completo tras este paso.

6. **Ejecución del Pipeline (Workflow Trigger):** Un desarrollador realiza un push de código, lo que detona el runner de GitHub Actions.

7. **Inyección de Secretos:** GitHub Actions inyecta el token almacenado (`SONAR_TOKEN`) en el entorno seguro del runner efímero.

8. **Autenticación y Análisis (Uso):** El scanner de SonarQube (Maven/Gradle/CLI) envía el token como header `Authorization: Bearer <token>` hacia la API de SonarQube Cloud. La API valida el token opaco contra su almacén interno y autoriza el análisis.

9. **Protección de Transporte:** Todas las comunicaciones se realizan obligatoriamente sobre **TLS 1.2 o superior** (HTTPS exclusivo). HTTP no está soportado.

10. **Finalización y Limpieza:**
    - Al terminar el job de GitHub, el runner se destruye, eliminando el token de la memoria.
    - El token permanece válido hasta su fecha de expiración configurada.
    - Tokens inactivos por 60+ días son eliminados automáticamente por la plataforma.

---

## 4. Controles Compensatorios (mTLS y WAF)

Dado que es una solución SaaS Multi-tenant que **no soporta mTLS forzado por cliente** en endpoints públicos, la seguridad se garantiza mediante controles de red y aplicación en capas:

### Protecciones de Red:
| Control | Descripción |
|---------|-------------|
| **AWS VPC** | Cargas de trabajo en redes privadas detrás de firewalls |
| **Security Groups** | Default-deny, solo HTTPS/443 vía load balancers |
| **AWS Shield Standard** | Protección DDoS en el borde de red |

### Protecciones de Aplicación:
| Control | Descripción |
|---------|-------------|
| **AWS WAF** | Firewall de Aplicaciones Web bloqueando exploits comunes |
| **Rate Limiting** | Limitación de tasa de API para prevenir abuso (HTTP 429) |
| **Tenant Scoping** | Sin APIs de acceso cruzado entre empresas/organizaciones |
| **IP Allow-lists** | Restricciones opcionales basadas en IP (Enterprise) |

### Controles del Sistema AWS Nitro:
| Control | Función |
|---------|---------|
| **Bandwidth Baseline vs Burst** | Previene que un tenant sature enlaces compartidos |
| **Límites PPS** | Apunta a ataques DoS usando paquetes pequeños |
| **Límites de Flujo Activo** | Protege contra ataques de agotamiento de estado |

### Resumen de Controles Compensatorios:
- **Cifrado:** Uso estricto de TLS 1.2/1.3 (equivalente a la seguridad de un túnel).
- **Autenticación de Aplicación:** La seguridad reside en la robustez del Token opaco (Identidad) y no en la red.
- **Protección WAF (AWS):** El WAF perimetral filtra y rechaza cualquier petición maliciosa antes de que llegue a la aplicación.

---

## 5. Certificaciones de Cumplimiento

SonarSource mantiene las siguientes certificaciones que respaldan la seguridad de la plataforma:

| Certificación | Estado | Fecha | Alcance |
|---------------|--------|-------|---------|
| **SOC 2 Type II** | ✅ Certificado | Febrero 2025 | SonarQube Server, Cloud, IDE |
| **ISO 27001:2022** | ✅ Certificado | Vigente | Sistema de Gestión de Seguridad de la Información |

---

## 6. Disposición de Datos (NIST SP 800-88)

La sanitización de medios y disposición de datos sigue el estándar **NIST SP 800-88**:

| Aspecto | Implementación |
|---------|----------------|
| **Estándar** | NIST SP 800-88 (Guidelines for Media Sanitization) |
| **Verificación** | Revisión de reportes AWS SOC 2 Type II |
| **Evidencia** | AWS EventBridge + CloudTrail logs |
| **Servicios Cubiertos** | EBS, RDS, KMS (automático), S3 (CloudTrail Data Events) |

---

## 7. Comparación con Snyk OAuth 2.0

| Aspecto | SonarQube Cloud (SOT) | Snyk (OAuth 2.0) |
|---------|----------------------|------------------|
| **Tipo de Token CI/CD** | Opaco estático con expiración | Dinámico JWT (1 hora) |
| **Formato de Token** | Bearer opaco (NO JWT) | JWT firmado (JWS/JWE) |
| **Rotación** | Manual/programática | Automática (cada 60 min) |
| **OAuth para CI/CD** | ❌ Solo para SSO de usuarios | ✅ Client Credentials |
| **Ventana de Exposición** | Hasta expiración configurada | Máximo 60 minutos |
| **Certificaciones** | SOC 2 Type II, ISO 27001 | SOC 2 Type II |

**Nota:** Aunque SonarQube Cloud utiliza tokens estáticos (vs tokens dinámicos de Snyk), los controles compensatorios (expiración corta, limpieza automática, TLS obligatorio, WAF, rate limiting) proporcionan un nivel de seguridad equivalente.

---

Quedamos atentos a tu confirmación para proceder con el cierre del hallazgo en la herramienta.

Atentamente,

**Flor Ivett Soto / Jose David Santander**
Equipo de Integración Técnica SonarQube Cloud

---

*Fuentes:*
- Respuesta Oficial SonarSource al Cuestionario SASA (17 de Diciembre 2025)
- [Managing Scoped Organization Tokens](https://docs.sonarsource.com/sonarcloud/administering-sonarcloud/scoped-organization-tokens)
- [Trust Center](https://www.sonarsource.com/trust-center/)
- [SOC 2 Type II Compliance](https://www.sonarsource.com/blog/sonar-earns-soc-2-type-ii-compliance/)
