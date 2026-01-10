
# Security Audit Documentation: Snyk SaaS Assessment (Corrected)
**Project:** CART / CSMQ Compliance Review
**Client:** Banamex (SASA Security Team & Tech Leadership)
**Vendor:** Snyk (ISO/Engineering Team)
**Date of Assessment:** December 9, 2025 (Meeting) & December 11, 2025 (Resolution)

## 1. Executive Summary
The Banamex Security Auditor (Alex) identified three primary compliance blockers regarding Snyk's integration with GitHub Actions and general infrastructure. The critical blocker was the nature of the `SNYK_TOKEN` (Connection #11).

Initially, there was ambiguity regarding whether this token was dynamic or static. Following the meeting, Snyk clarified that the token is a **static shared secret**. To meet Banamex's requirement for **mandatory programmatic rotation**, the architecture was adjusted to utilize **Service Accounts** instead of Personal User Tokens. This change, combined with compensating controls (HMAC signatures and TLS), allowed the compliance finding to be closed.

---

## 2. Meeting Participants & Roles
* **Alex (Banamex):** Lead Security Auditor (SASA). Responsible for technical validation and identifying "Non-Compliant" findings.
* **Flor Ivett Soto (Banamex):** Tech Lead / Project Manager. Responsible for managing the implementation and facilitating communication between the Auditor and the Vendor.
* **Colin (Snyk):** Information Security Officer (ISO). Provided architectural defense and technical clarifications.
* **Javier Garza (Snyk):** Account Manager/Facilitator.

---

## 3. Technical Findings & Resolution Log

### Finding A: Nature of "Viewer/Action Token" (Connection #11)
* **The Concern:** The auditor required the token used for GitHub Actions integration to be dynamic/ephemeral to minimize attack surface.
* **Initial Discussion:** Snyk (Colin) hypothesized the token was a dynamic JWT with a short TTL (Time-To-Live).
* **Correction (Post-Meeting):** Snyk confirmed via email that the standard `SNYK_TOKEN` is actually a **static API Token** (Shared Secret) generated via a high-entropy random number generator.
* **The Blocker:** A static token typically fails the "Automatic Rotation" control.
* **Final Resolution:** Snyk proposed implementing **Service Accounts**. Unlike personal tokens, Service Account secrets can be managed via the Snyk API (`POST /service_accounts/{id}/secrets`), enabling fully automated, programmatic rotation scripts.
    * **Status:** **Resolved (Conditional)** based on Service Account implementation.

### Finding B: Lack of Mutual TLS (mTLS) 1.3
* **The Concern:** Banamex standards require mTLS for infrastructure authentication to prevent unauthorized device connections.
* **Snyk Defense:** As a multi-tenant SaaS, issuing client-side certificates for every customer is operationally unfeasible.
* **Compensating Control:** Snyk relies on:
    1.  **Transport:** Standard TLS 1.2/1.3 for encryption in transit.
    2.  **App-Layer Auth:** Use of HMAC-SHA signatures (for Webhooks/Integrations) and strong Bearer tokens. The secret itself is never transmitted over the wire during signing operations.
* **Status:** **Accepted as Risk Exception.** The auditor accepted that strong application-layer authentication effectively mitigates the risk in a multi-tenant environment.

### Finding C: Lack of Network Segregation (VPCs/VPNs)
* **The Concern:** Banamex requested IP allow-listing or Private Link (VPC) connections to segregate their traffic from other tenants.
* **Snyk Defense:** Snyk adopts a "Zero Trust" style approach where security relies on **Identity and Encryption** rather than network pipes. They do not support VPC peering for public API consumption.
* **Status:** **Accepted.** The auditor accepted the defense provided that the authentication mechanisms (OAuth, Tokens) are robust.

---

## 4. Technical Architecture Details

### Cryptography & Key Management
* **Key Storage:** Private keys for signing JWTs are stored in **AWS KMS** (Key Management Service) and are never exported.
* **GitHub App Auth:** Uses a private/public key pair (RSA 2048/4096-bit). The private key signs a JWT which is exchanged for a short-lived GitHub installation token.
* **Key Rotation:**
    * *GitHub App Keys:* Rotated yearly; supports multiple active keys to allow zero-downtime rotation.
    * *API Tokens:* Manual "Revoke & Regenerate" via UI, or programmatic via API (Service Accounts only).

### Authentication Flows
* **Standard User:** OIDC / SAML (SSO) -> Generates JWE/JWS.
* **CI/CD (GitHub Actions):**
    * *Method:* Service Account Token (Recommended for Banamex).
    * *Flow:* The token is stored as a GitHub Secret (`${{ secrets.SNYK_TOKEN }}`). It is used to authenticate requests to the Snyk API. The token itself acts as a Bearer credential or is used to sign payloads (HMAC).

---

## 5. Artifacts & Evidence Provided

The following documentation was provided to Banamex (via Flor/Javier) to close the audit findings:

1.  **Architecture Diagrams:** Updated visual diagrams showing Connection #11 (GitHub Actions <-> Snyk).
2.  **Rotation Documentation:**
    * *Manual:* [Revoke and regenerate a Snyk API token](https://docs.snyk.io/snyk-api/authentication-for-api/revoke-and-regenerate-a-snyk-api-token).
    * *Programmatic (The Fix):* [Manage Service Accounts & Secrets via API](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/manage-service-accounts-using-the-snyk-api).

---

## 6. Conclusion
The audit began with a potential "Non-Compliant" rating due to the static nature of the integration token. By shifting the architecture choice from **Personal Tokens** to **Service Accounts**, Snyk demonstrated the ability to meet Banamex's strict automation requirements. The lack of mTLS and VPC peering was accepted as a standard SaaS risk exception, compensated by strong TLS usage and HMAC signing.

---

## Appendix A: Formal Remediation Communication (Spanish)

**To:** Alejandro (Banamex Auditor)
**Cc:** Flor Ivett Soto (Banamex Tech Lead)
**Subject:** Evidencia Técnica y Solución Arquitectónica: Cumplimiento de Rotación Programática de SNYK_TOKEN

**Estimado Alejandro,**

En seguimiento a nuestra reunión de auditoría técnica y con el objetivo de dar cierre al hallazgo marcado como "Incompleto" respecto a la naturaleza del token utilizado en la integración con GitHub Actions (referenciado como Conexión #11), enviamos la siguiente clarificación técnica definitiva y la propuesta de remediación.

Tras la revisión con nuestro equipo de seguridad (ISO) y en atención a su requerimiento de **rotación programática obligatoria**, confirmamos la siguiente estrategia:

**1. Naturaleza del Token (Corrección Técnica)**
El `SNYK_TOKEN` utilizado es un "Secreto Compartido" (Shared Secret) estático de alta entropía y no un JWT dinámico. Sin embargo, la arquitectura de seguridad para su implementación se ha ajustado para cumplir con sus estándares de automatización.

**2. Implementación de Cuenta de Servicio (Cumplimiento de Rotación Programática)**
Para satisfacer el control de **rotación programática obligatoria**, la integración no se realizará mediante un token de usuario personal (que requiere rotación manual), sino a través de una **Cuenta de Servicio (Service Account)**.

Esto garantiza el cumplimiento mediante los siguientes mecanismos:

* **Rotación vía API:** A diferencia de los usuarios estándar, las Cuentas de Servicio permiten la gestión de sus secretos (tokens) programáticamente a través de la API de Snyk. Esto habilita la implementación de scripts o herramientas de gestión de secretos para rotar las credenciales automáticamente y sin intervención humana.
* **Mecanismo de Firma (HMAC-SHA):** El token no viaja en texto plano en cada petición; se utiliza para firmar criptográficamente las solicitudes, mitigando el riesgo de interceptación.
* **Aislamiento:** El token está asociado estrictamente a un servicio y no a una identidad humana, reduciendo la superficie de ataque.

**3. Evidencia Documental**
Adjunto a este correo encontrará los diagramas de arquitectura actualizados. Asimismo, compartimos la documentación oficial que valida la capacidad de gestión programática de secretos para Cuentas de Servicio:

* **Gestión de Cuentas de Servicio y Rotación:** [Manage Service Accounts & Secrets via API](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/manage-service-accounts-using-the-snyk-api).
* **Configuración en CI/CD:** [GitHub Actions for Snyk setup](https://docs.snyk.io/developer-tools/snyk-ci-cd-integrations/github-actions-for-snyk-setup-and-checking-for-vulnerabilities).

Consideramos que el uso de Cuentas de Servicio, sumado a la protección TLS y la firma HMAC, cierra definitivamente la brecha de seguridad y cumple con la exigencia de automatización del ciclo de vida del token.

Quedamos atentos a su confirmación para proceder con el cierre de este punto en el cuestionario.

Atentamente,

**[Tu Nombre/Cargo]**
En representación del equipo de Seguridad de Snyk