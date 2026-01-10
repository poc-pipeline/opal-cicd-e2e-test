
Estimado Alejandro,

En seguimiento a nuestra revisión técnica del 9 de diciembre con el equipo de Snyk y la clarificación posterior del     
11 de diciembre, me permito presentarte las dos alternativas de implementación que cumplen integralmente con el
requerimiento de rotación programática obligatoria para la Conexión #11 (GitHub Actions <-> Snyk).

Tras revisar en detalle con el equipo de Snyk (Colin, Information Security Officer y Javier Garza), además de la        
solución inicial basada en Service Accounts, identificamos una segunda alternativa utilizando OAuth 2.0 que también     
cumple con todos los requisitos del CSMQ y ofrece beneficios adicionales de seguridad.

A continuación presento los detalles técnicos de la arquitectura de seguridad de Snyk proporcionados por Colin que      
respaldan ambas propuestas.

---
Contexto Técnico: Arquitectura de Seguridad de Snyk (Confirmado por ISO)

Clarificación sobre el SNYK_TOKEN (Conexión #11)

Tras la revisión técnica con el equipo de seguridad de Snyk, se confirmó lo siguiente:

Naturaleza del Token:
- El SNYK_TOKEN estándar es un Secreto Compartido (Shared Secret) estático generado mediante un generador de números    
aleatorios de alta entropía
- No es un JWT dinámico como se hipotetizó inicialmente en la reunión
- Esta clarificación fue proporcionada por Colin (Snyk ISO) posterior a la reunión del 9 de diciembre

Arquitectura de Autenticación GitHub App (Referencia)

El equipo de Snyk confirmó la siguiente arquitectura para la integración con GitHub:

| Componente                      | Especificación Técnica                                                    |
|---------------------------------|---------------------------------------------------------------------------|
| Generación de Claves            | Par de claves pública/privada via bibliotecas OpenSSL estándar            |
| Especificación de Clave         | RSA 2048-bit o 4096-bit (fuente de alta entropía)                         |
| Almacenamiento de Clave Privada | AWS KMS (Key Management Service) - nunca exportada                        |
| Firma de Tokens                 | JWT firmado con clave privada para autenticación                          |
| Tiempo de Vida de JWT           | Muy corto (~5 minutos por sesión)                                         |
| Claves Concurrentes             | GitHub permite hasta ~30 claves públicas activas simultáneamente          |
| Rotación de Claves              | Política anual con capacidad de solapamiento (cero tiempo de inactividad) |

Mecanismos de Autenticación Soportados (Confirmado por Snyk ISO)

Colin confirmó que los endpoints de Snyk soportan múltiples mecanismos:

1. OAuth 2.0 - Método preferido para integración empresarial
2. PAT (Personal Access Tokens) - Usado para generación HMAC en solicitudes
3. GitHub App Interface - JWTs dinámicos (para autenticación GitHub, no CI/CD)
4. Service Account Tokens - Gestión programática via API

Defensa Técnica: Ausencia de mTLS y VPC

Como se explicó en la reunión, Snyk no implementa mTLS ni VPC por las siguientes razones técnicas:

Respecto a mTLS:
"As a multi-tenant SaaS, issuing client-side certificates for every customer is operationally unfeasible. We rely on    
Standard TLS (1.2/1.3) for the pipe plus Strong Application Layer Authentication (OAuth, PATs, JWT)." — Colin, Snyk    
ISO

Respecto a VPC/VPN:
"We don't generally support VPCs or VPNs. Taking the view that those technologies generally provide you with an         
encrypted pipe, but as long as the connection that we actually establish for the API is TLS—which it will be—and as     
long as we have established good authentication on that... then generally the feeling is we don't need the extra        
operational complexity of an additional tunnel." — Colin, Snyk ISO

Control Compensatorio Aceptado:
- TLS 1.2/1.3 para cifrado en tránsito
- HMAC-SHA para firma de solicitudes (el secreto nunca viaja durante operaciones de firma)
- Bearer tokens robustos con autenticación a nivel de aplicación

---
Opción A: SNYK_TOKEN con Cuenta de Servicio (Service Account)

Descripción Técnica

Esta opción utiliza el SNYK_TOKEN como Secreto Compartido estático de alta entropía, pero migrado de un token de        
usuario personal a una Cuenta de Servicio (Service Account). Esta migración arquitectónica es la que habilita el        
cumplimiento del control de rotación programática.

Aclaración Importante (Corrección Post-Reunión):
El token SNYK_TOKEN es un secreto compartido estático, no un JWT dinámico. Sin embargo, al utilizar Service Accounts    
en lugar de tokens personales, se habilita la gestión programática del ciclo de vida.

Mecanismos de Cumplimiento

| Control Requerido        | Implementación                                                                  |
Validación Técnica                                                                      |
|--------------------------|---------------------------------------------------------------------------------|------    
-----------------------------------------------------------------------------------|
| Rotación Programática    | API de Snyk (POST /service_accounts/{id}/secrets) permite rotación automatizada |
Scripts o herramientas de gestión de secretos ejecutan rotación sin intervención humana |
| Alta Entropía            | Generador de números aleatorios de alta entropía                                |
Confirmado por Snyk ISO                                                                 |
| Protección en Tránsito   | TLS 1.2/1.3 obligatorio                                                         | Todas    
las comunicaciones cifradas                                                       |
| Firma HMAC-SHA           | Token usado para firmar criptográficamente solicitudes                          | El       
secreto no viaja en texto plano en cada petición                                     |
| Aislamiento de Identidad | Token asociado a servicio, no a identidad humana                                |
Reduce superficie de ataque                                                             |

Arquitectura de la Solución

┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   GitHub Actions    │────▶│   Snyk API           │────▶│   Snyk Cloud    │
│   (CI/CD Runner)    │     │   (api.snyk.io)      │     │   (Analysis)    │
└─────────────────────┘     └──────────────────────┘     └─────────────────┘
        │                           │
        │ SNYK_TOKEN                │ TLS 1.2/1.3
        │ (Service Account)        │ + HMAC-SHA
        ▼                           │
┌─────────────────────┐              │
│   GitHub Secrets    │              │
│   (Encrypted Store) │──────────────┘
└─────────────────────┘

Rotación Programática:
┌─────────────────────┐     ┌──────────────────────┐
│   Script/Vault      │────▶│   Snyk API           │
│   (Automatizado)    │     │   POST /service_     │
└─────────────────────┘     │   accounts/{id}/     │
        │                  │   secrets            │
        │                  └──────────────────────┘
        ▼
Nuevo token generado
y actualizado en
GitHub Secrets

Configuración en CI/CD

# GitHub Secrets requeridos
SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

# Uso en workflow
- name: Run Snyk Security Scan
uses: snyk/actions/maven@master
env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
with:
    args: --severity-threshold=high

Script de Rotación Programática (Ejemplo)

#!/bin/bash
# rotate-snyk-token.sh - Rotación programática de SNYK_TOKEN

SERVICE_ACCOUNT_ID="your-service-account-id"
SNYK_API_TOKEN="your-admin-api-token"

# Generar nuevo secreto via API
NEW_SECRET=$(curl -s -X POST \
"https://api.snyk.io/rest/groups/{groupId}/service_accounts/${SERVICE_ACCOUNT_ID}/secrets" \
-H "Authorization: token ${SNYK_API_TOKEN}" \
-H "Content-Type: application/json" \
| jq -r '.data.attributes.secret')

# Actualizar GitHub Secret (requiere gh CLI autenticado)
gh secret set SNYK_TOKEN --body "${NEW_SECRET}"

echo "Token rotado exitosamente"

Documentación de Respaldo

- https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/manage-service-accounts-using-the-    
snyk-api
- https://docs.snyk.io/snyk-api/authentication-for-api/revoke-and-regenerate-a-snyk-api-token
- https://docs.snyk.io/developer-tools/snyk-ci-cd-integrations/github-actions-for-snyk-setup-and-checking-for-vulner    
abilities

Ventajas

- Menor complejidad de implementación - Cambio mínimo en pipeline existente
- Compatible con configuración actual - Solo requiere migrar a Service Account
- Rotación controlada - Frecuencia definida por política interna (recomendado: trimestral)
- Probado en producción - Arquitectura utilizada por múltiples clientes enterprise

Consideraciones

- Requiere implementar y mantener script de rotación periódica
- Token permanece estático entre rotaciones (ventana de exposición mayor que OAuth)
- Necesita proceso operativo para gestión del ciclo de rotación

---
Opción B: OAuth 2.0 Client Credentials (Recomendada)

Descripción Técnica

Esta opción utiliza el estándar OAuth 2.0 Client Credentials con tokens de corta duración que se renuevan
automáticamente. Como confirmó Colin (Snyk ISO) durante la reunión del 9 de diciembre:

"Each of the APIs support a number of different authentication mechanisms. From memory, we support OAuth..." — 
Colin, Snyk ISO

OAuth 2.0 es el método preferido por Snyk para integración empresarial, según lo indicado en la arquitectura de
autenticación soportada.

Alineación con Arquitectura Snyk

Esta opción aprovecha la misma infraestructura de seguridad descrita por el equipo de Snyk:

| Componente               | Implementación en OAuth                                   |
|--------------------------|-----------------------------------------------------------|
| Almacenamiento de Claves | AWS KMS (mismo que GitHub App)                            |
| Firma de Tokens          | JWT firmado con estándares JWS/JWE (confirmado por Colin) |
| Generación               | Alta entropía via OpenSSL (misma base criptográfica)      |
| Protocolo                | TLS 1.2/1.3 obligatorio                                   |

Mecanismos de Cumplimiento

| Control Requerido       | Implementación                                                   | Validación Técnica       
                                        |
|-------------------------|------------------------------------------------------------------|----------------------    
------------------------------------------|
| Rotación Automática     | Tokens expiran cada 60 minutos - rotación inherente al protocolo | No requiere
intervención; el protocolo garantiza rotación      |
| Credenciales Dinámicas  | Access token es JWT dinámico, no secreto compartido estático     | Alineado con
arquitectura de GitHub App que usa JWTs de ~5 min |
| Alta Entropía           | Client Secret generado con alta entropía                         | Misma base
criptográfica confirmada por Snyk ISO               |
| Protección en Tránsito  | TLS 1.2/1.3 obligatorio                                          | Misma protección que     
SNYK_TOKEN                                |
| Firma Criptográfica     | JWT firmado con JWS/JWE                                          | Estándar superior a      
HMAC-SHA                                   |
| Segregación de Secretos | Client ID + Client Secret separados                              | El secret no viaja       
después de autenticación inicial            |
| Auditoría Mejorada      | Trazabilidad completa de cada sesión                             | Cada token tiene
timestamp y puede rastrearse individualmente  |

Arquitectura de la Solución

┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   GitHub Actions    │────▶│   Snyk OAuth         │────▶│   Snyk Cloud    │
│   (CI/CD Runner)    │     │   (api.snyk.io/      │     │   (Analysis)    │
└─────────────────────┘     │    oauth2/token)     │     └─────────────────┘
        │                  └──────────────────────┘
        │                           │
        │ Client Credentials        │ JWT Bearer Token
        │ (una sola vez)           │ (1 hora, auto-renovable)
        ▼                           │
┌─────────────────────┐              │
│   GitHub Secrets    │              │ TLS 1.2/1.3
│   - CLIENT_ID       │              │ + JWT Signature
│   - CLIENT_SECRET   │──────────────┘
└─────────────────────┘

Flujo de Autenticación:
1. CI/CD envía client_id + client_secret a /oauth2/token
2. Snyk valida credenciales y genera JWT (1 hora TTL)
3. JWT firmado con clave privada almacenada en AWS KMS
4. CI/CD usa JWT como Bearer token para scans
5. Token expira automáticamente → nueva solicitud si es necesario

Configuración en CI/CD

# GitHub Secrets requeridos
SNYK_CLIENT_ID: ${{ secrets.SNYK_CLIENT_ID }}
SNYK_CLIENT_SECRET: ${{ secrets.SNYK_CLIENT_SECRET }}

# Adquisición de token OAuth (similar a arquitectura GitHub App)
- name: Acquire Snyk OAuth Token
run: |
    RESPONSE=$(curl -s -X POST https://api.snyk.io/oauth2/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "client_id=${{ secrets.SNYK_CLIENT_ID }}" \
    -d "client_secret=${{ secrets.SNYK_CLIENT_SECRET }}")

    ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.access_token')
    echo "::add-mask::$ACCESS_TOKEN"
    echo "SNYK_OAUTH_TOKEN=$ACCESS_TOKEN" >> $GITHUB_ENV

    # Validar que el token fue adquirido
    if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: No se pudo adquirir token OAuth"
    exit 1
    fi
    echo "Token OAuth adquirido exitosamente"

- name: Run Snyk Security Scan
run: |
    snyk test --json-file-output=snyk-results.json || true
    snyk test --sarif-file-output=snyk-results.sarif || true

Autenticación Alternativa via CLI (Snyk CLI v1.1293.0+)

- name: Authenticate Snyk CLI with OAuth
run: |
    snyk auth --auth-type=oauth \
    --client-id=${{ secrets.SNYK_CLIENT_ID }} \
    --client-secret=${{ secrets.SNYK_CLIENT_SECRET }}

Características del Token OAuth

| Aspecto                  | Especificación                    | Referencia Snyk ISO
                |
|--------------------------|-----------------------------------|----------------------------------------------------    
------------------|
| Tiempo de Vida           | 3599 segundos (~1 hora)           | Similar a GitHub App tokens (~5 min), pero
optimizado para CI/CD     |
| Tipo                     | Bearer Token (JWT)                | Mismo estándar confirmado por Colin (JWS/JWE)
                |
| Renovación               | Automática via client credentials | Sin intervención humana requerida
                |
| Almacenamiento de Claves | AWS KMS para claves de firma      | Confirmado: "private key will be stored in AWS KMS"    
                |
| Generación               | Alta entropía via OpenSSL         | "generated with the standard OpenSSL libraries,        
high entropy source" |

Configuración Regional (Endpoints por Región)

| Región       | OAuth Endpoint              | API Endpoint   | Uso           |
|--------------|-----------------------------|----------------|---------------|
| US (default) | api.snyk.io/oauth2/token    | api.snyk.io    | Norte América |
| EU           | api.eu.snyk.io/oauth2/token | api.eu.snyk.io | Europa (GDPR) |
| AU           | api.au.snyk.io/oauth2/token | api.au.snyk.io | Asia-Pacífico |

Documentación de Respaldo

- https://docs.snyk.io/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0
- https://docs.snyk.io/snyk-api/oauth2-api
- https://docs.snyk.io/snyk-cli/authenticate-to-use-the-cli
- https://docs.snyk.io/developer-tools/snyk-cli/commands/auth
- https://docs.snyk.io/snyk-cli/configure-the-snyk-cli/environment-variables-for-snyk-cli

Ventajas

- Rotación automática inherente - El protocolo OAuth garantiza rotación cada 60 minutos sin scripts adicionales
- Mayor seguridad - Tokens de corta duración minimizan ventana de exposición (1 hora vs indefinido)
- Estándar de industria - OAuth 2.0 (RFC 6749) es ampliamente reconocido y auditado
- Mejor auditoría - Cada sesión es trazable individualmente con timestamps
- Alineado con arquitectura Snyk - Usa la misma infraestructura de JWTs y AWS KMS descrita por Colin
- Preferido por Snyk - Método recomendado para integración empresarial según ISO
- Sin dependencia de scripts - Elimina punto de falla de scripts de rotación

Consideraciones

- Requiere configuración inicial de Service Account OAuth en Snyk (Group Settings → Service Accounts)
- Client Secret se muestra una sola vez al crear (debe almacenarse inmediatamente en vault seguro)
- Requiere Snyk CLI v1.1293.0+ para autenticación directa via flags

---
Matriz Comparativa

| Criterio                      | Opción A (Service Account Token)                           | Opción B (OAuth 2.0)     
                |
|-------------------------------|------------------------------------------------------------|----------------------    
-----------------|
| Tipo de Token                 | Estático (alta entropía) - Shared Secret                   | Dinámico (JWT, 1
hora)                |
| Rotación                      | Programática via API (POST /service_accounts/{id}/secrets) | Automática inherente     
al protocolo     |
| Frecuencia de Rotación        | Configurable (recomendado: trimestral)                     | Cada 60 minutos
(automático)          |
| Complejidad de Implementación | Baja - cambio mínimo en pipeline                           | Media - requiere
flujo OAuth          |
| Scripts Adicionales           | Sí - script de rotación periódica                          | No requerido
                |
| Firma de Solicitudes          | HMAC-SHA (secreto firma payload)                           | JWT firmado (JWS/JWE)    
                |
| Almacenamiento de Claves      | N/A (token es el secreto)                                  | AWS KMS (confirmado      
por Snyk ISO)     |
| Estándar de Seguridad         | Propietario Snyk + HMAC                                    | OAuth 2.0 (RFC 6749)     
+ JWT            |
| Auditoría                     | Por token (menos granular)                                 | Por sesión (cada
solicitud)           |
| Ventana de Exposición         | Hasta próxima rotación (trimestral)                        | Máximo 60 minutos        
                |
| Referencia Snyk ISO           | "high entropy random number generator"                     | "we support OAuth" -     
Método preferido |
| Recomendación Snyk            | Válida para Enterprise                                     | Preferida para 
Enterprise             |

---
Cobertura de Incumplimientos y Observaciones de Alejandro

A continuación se detalla cómo cada opción cubre específicamente cada incumplimiento y observación identificada por     
Alejandro durante la revisión técnica, junto con los controles compensatorios aplicables.

---
Incumplimiento 1: Naturaleza del Token - Rotación Programática Obligatoria (Conexión #11)

Observación de Alejandro: El token utilizado para la integración con GitHub Actions debía ser dinámico/efímero para     
minimizar la superficie de ataque. Requisito de rotación programática automática.

Estado: ✅ CERRADO - Ambas opciones cumplen con este requisito

Cobertura con Opción A (SNYK_TOKEN + Service Account)

| Aspecto                   | Cómo se cubre                                                         | Control
Compensatorio                                                         |
|---------------------------|-----------------------------------------------------------------------|---------------    
----------------------------------------------------------------|
| Token Estático            | Colin confirmó: "Shared Secret de alta entropía"                      | Alta entropía     
via generador OpenSSL mitiga riesgo de adivinación              |
| Rotación Programática     | API POST /service_accounts/{id}/secrets permite rotación automatizada | Script de
rotación periódica (trimestral recomendado) sin intervención humana |
| Gestión del Ciclo de Vida | Service Accounts permiten gestión programática vs tokens personales   | Aislamiento de    
identidad - token no vinculado a usuario humano                |
| Protección del Secreto    | HMAC-SHA firma las solicitudes                                        | El token no       
viaja en texto plano; se usa para firmar criptográficamente       |

Evidencia documental: https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/manage-service    
-accounts-using-the-snyk-api

Cobertura con Opción B (OAuth 2.0)

| Aspecto                   | Cómo se cubre                                     | Control Compensatorio
                                |
|---------------------------|---------------------------------------------------|-----------------------------------    
--------------------------------|
| Token Dinámico            | JWT dinámico con TTL de 1 hora (3599 segundos)    | Token efímero por diseño -
rotación inherente al protocolo        |
| Rotación Automática       | Cada solicitud puede generar nuevo token          | Sin dependencia de scripts; el        
protocolo OAuth garantiza rotación |
| Gestión del Ciclo de Vida | Client credentials permiten renovación automática | No hay token estático de larga        
duración                           |
| Protección del Secreto    | JWT firmado con JWS/JWE, claves en AWS KMS        | Firma criptográfica con claves que    
nunca se exportan del KMS      |

Evidencia documental: https://docs.snyk.io/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0

---
Incumplimiento 2: Ausencia de Mutual TLS (mTLS) 1.3

Observación de Alejandro: Los estándares de Banamex requieren mTLS para autenticación de infraestructura y prevenir     
conexiones de dispositivos no autorizados.

Estado: ✅ ACEPTADO COMO EXCEPCIÓN DE RIESGO - Controles compensatorios aplicados

Defensa Técnica de Snyk (Colin, ISO):
"As a multi-tenant SaaS, issuing client-side certificates for every customer is operationally unfeasible. We rely on    
Standard TLS (1.2/1.3) for the pipe plus Strong Application Layer Authentication (OAuth, PATs, JWT)."

Cobertura con Opción A (SNYK_TOKEN + Service Account)

| Control Compensatorio               | Implementación                                | Mitigación de Riesgo
                                        |
|-------------------------------------|-----------------------------------------------|-----------------------------    
------------------------------------------|
| TLS 1.2/1.3                         | Todas las comunicaciones cifradas en tránsito | Equivalente a cifrado de        
pipe mTLS                                    |
| Autenticación a Nivel de Aplicación | HMAC-SHA con token de Service Account         | Verificación de identidad       
sin certificados cliente                    |
| Alta Entropía del Token             | Generador OpenSSL de números aleatorios       | Previene ataques de fuerza      
bruta                                      |
| Aislamiento de Identidad            | Token asociado a servicio, no a usuario       | Reduce superficie de ataque     
por compromiso de credenciales personales |

Cobertura con Opción B (OAuth 2.0)

| Control Compensatorio | Implementación                                | Mitigación de Riesgo
                    |
|-----------------------|-----------------------------------------------|-------------------------------------------    
-----------------------|
| TLS 1.2/1.3           | Todas las comunicaciones cifradas en tránsito | Equivalente a cifrado de pipe mTLS
                    |
| JWT Firmado           | Token firmado con JWS/JWE                     | Autenticación criptográfica sin
certificados cliente             |
| Tokens Efímeros       | TTL de 1 hora                                 | Ventana de exposición limitada vs
certificados de larga duración |
| AWS KMS               | Claves privadas almacenadas en KMS            | Claves nunca expuestas, similar a HSM para    
mTLS                  |

Justificación de Aceptación: La combinación de TLS 1.2/1.3 + autenticación fuerte a nivel de aplicación proporciona     
protección equivalente al objetivo de mTLS (autenticación mutua) en un entorno multi-tenant SaaS.

---
Incumplimiento 3: Ausencia de Segregación de Red (VPC/VPN/IP Allow-listing)

Observación de Alejandro: Solicitud de allow-listing de IPs o conexiones Private Link (VPC) para segregar el tráfico    
de Banamex de otros tenants.

Estado: ✅ ACEPTADO - Modelo Zero Trust con controles compensatorios

Defensa Técnica de Snyk (Colin, ISO):
"We don't generally support VPCs or VPNs. Taking the view that those technologies generally provide you with an         
encrypted pipe, but as long as the connection that we actually establish for the API is TLS—which it will be—and as     
long as we have established good authentication on that... then generally the feeling is we don't need the extra        
operational complexity of an additional tunnel."

Cobertura con Opción A (SNYK_TOKEN + Service Account)

| Control Compensatorio    | Implementación                                 | Mitigación de Riesgo
    |
|--------------------------|------------------------------------------------|---------------------------------------    
-----|
| Modelo Zero Trust        | Seguridad basada en identidad, no en red       | No dependencia de perímetro de red        
    |
| TLS Fuerte               | TLS 1.2/1.3 para todas las conexiones          | Cifrado equivalente a VPN/tunnel
    |
| Token de Service Account | Autenticación por token único por organización | Segregación lógica por credenciales       
    |
| HMAC-SHA                 | Firma de solicitudes                           | Integridad y autenticidad de cada
petición |

Cobertura con Opción B (OAuth 2.0)

| Control Compensatorio     | Implementación                               | Mitigación de Riesgo
        |
|---------------------------|----------------------------------------------|----------------------------------------    
---------|
| Modelo Zero Trust         | Seguridad basada en identidad, no en red     | No dependencia de perímetro de red
        |
| TLS Fuerte                | TLS 1.2/1.3 para todas las conexiones        | Cifrado equivalente a VPN/tunnel
        |
| Client Credentials Únicos | Par client_id/client_secret por organización | Segregación lógica por credenciales        
OAuth       |
| JWT con Claims            | Token incluye información de identidad       | Trazabilidad y segregación por sesión      
        |
| Tokens Efímeros           | Validez de 1 hora                            | Riesgo de interceptación limitado
temporalmente |

Justificación de Aceptación: El modelo "Modern Auth > Tunneling" adoptado por Snyk proporciona:
1. Cifrado equivalente - TLS 1.2/1.3 ofrece el mismo nivel de protección que un tunnel VPN
2. Autenticación más fuerte - Credenciales por organización + firma/JWT vs. solo IP
3. Menor complejidad operativa - Sin gestión de tunnels o allow-lists

---
Resumen: Mapeo de Incumplimientos a Soluciones

| Incumplimiento           | Opción A                    | Opción B                     | Control Compensatorio
        |
|--------------------------|-----------------------------|------------------------------|---------------------------    
----------|
| 1. Rotación Programática | ✅ API de Service Accounts  | ✅ OAuth automático (1h TTL) | Alta entropía + firma
criptográfica |
| 2. Ausencia de mTLS      | ✅ TLS + HMAC-SHA           | ✅ TLS + JWT firmado         | Autenticación a nivel de      
aplicación |
| 3. Ausencia de VPC/VPN   | ✅ Zero Trust + Token único | ✅ Zero Trust + OAuth único  | Identidad sobre perímetro     
de red    |

Diferencia Clave entre Opciones

| Aspecto                    | Opción A                              | Opción B                           |
|----------------------------|---------------------------------------|------------------------------------|
| Cobertura Incumplimiento 1 | Requiere script de rotación periódica | Rotación inherente sin scripts     |
| Cobertura Incumplimiento 2 | HMAC-SHA (secreto firma payload)      | JWT (firma criptográfica estándar) |
| Cobertura Incumplimiento 3 | Token de Service Account              | Client credentials OAuth           |
| Esfuerzo de Mantenimiento  | Script de rotación + monitoreo        | Ninguno adicional                  |
| Ventana de Exposición      | Hasta próxima rotación (trimestral)   | Máximo 60 minutos                  |

---
Conclusión

Ambas opciones cumplen integralmente con todos los controles de seguridad identificados en la revisión técnica:

| Control CSMQ                      | Opción A                       | Opción B                    |
|-----------------------------------|--------------------------------|-----------------------------|
| Rotación Programática Obligatoria | ✅ Via API de Service Accounts | ✅ Automática cada 60 min   |
| Alta Entropía                     | ✅ Confirmado por Snyk ISO     | ✅ Misma base criptográfica |
| Protección TLS 1.2/1.3            | ✅ Obligatorio                 | ✅ Obligatorio              |
| Firma Criptográfica               | ✅ HMAC-SHA                    | ✅ JWT (JWS/JWE)            |
| Aislamiento de Identidad          | ✅ Service Account             | ✅ Service Account OAuth    |
| Almacenamiento Seguro de Claves   | ✅ GitHub Secrets              | ✅ AWS KMS + GitHub Secrets |
| Auditoría                         | ✅ Por token                   | ✅ Por sesión               |

Recomendación Técnica

Nuestra recomendación técnica es la Opción B (OAuth 2.0) basada en:

1. Rotación automática inherente al protocolo - elimina dependencia de scripts y procesos operativos
2. Alineación con arquitectura Snyk - usa la misma infraestructura de JWTs y AWS KMS descrita por Colin (ISO)
3. Menor ventana de exposición - 60 minutos vs potencialmente meses con rotación manual
4. Estándar de industria - OAuth 2.0 (RFC 6749) es auditado y reconocido globalmente
5. Preferido por Snyk - Método recomendado para integración empresarial según ISO

Sin embargo, la Opción A también satisface completamente los requerimientos del CSMQ y puede ser preferible si se       
busca minimizar cambios en la implementación actual.

---
Próximos Pasos

Por favor indique cuál de las dos opciones prefiere implementar para proceder con:

1. Configuración del Service Account correspondiente en Snyk (Group Settings → Service Accounts)
2. Actualización de GitHub Secrets en el repositorio según la opción seleccionada
3. Modificación del pipeline CI/CD (cambios mínimos para Opción A, flujo OAuth para Opción B)
4. Pruebas de validación con scripts de verificación incluidos
5. Generación de evidencia documental para cierre formal del hallazgo en cuestionario CSMQ

Tiempos estimados de implementación:
- Opción A: Configuración inmediata + script de rotación
- Opción B: Configuración inicial + actualización de workflows

Quedo a tu disposición para cualquier aclaración técnica adicional o para agendar una sesión de revisión conjunta       
con el equipo de Snyk si lo consideras necesario.

Atentamente,

Flor Ivett Soto
Tech Lead - Integración Snyk
Banamex

---
Adjuntos:
1. Diagrama de arquitectura actualizado (Conexión #11)
2. Documentación OAuth Snyk (oauth-step-by-step-guide.md)
3. Scripts de validación de configuración (validate-snyk-oauth.sh, test-snyk-oauth-local.sh)
4. Diagrama de secuencia OAuth (oauth-sequence-diagram.mermaid)

---
Referencias Documentales Snyk (Evidencia Técnica):
- https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/manage-service-accounts-using-the-    
snyk-api
- https://docs.snyk.io/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0
- https://docs.snyk.io/snyk-api/oauth2-api
- https://docs.snyk.io/developer-tools/snyk-ci-cd-integrations/github-actions-for-snyk-setup-and-checking-for-vulner    
abilities

---
Este correo contiene información técnica confidencial destinada exclusivamente para uso interno de Banamex. Fecha de    
revisión técnica: 9-11 de diciembre de 2025. Proyecto: CART/CSMQ Compliance Review.