Aquí tienes el borrador del correo redactado específicamente para cubrir los puntos solicitados por Alejandro durante la sesión, estructurado para que pueda copiar y pegar la información directamente en el registro del CSMQ.

Asunto: Información Complementaria CSMQ: Mecanismos de Autenticación y Flujo Paso a Paso - Integración Snyk/GitHub

Estimado Alejandro,

En seguimiento a nuestra sesión de hoy y para dar cierre a los puntos requeridos para el registro en el CSMQ, te comparto la información detallada sobre los métodos de autenticación y el flujo paso a paso del ciclo de vida de las credenciales.

A continuación, describimos los dos mecanismos soportados y el flujo unificado de integración.

1. Métodos de Autenticación y Privilegios

La arquitectura de seguridad de Snyk para cuentas de servicio se basa en los siguientes pilares:

Identidad y Acceso (IAM): La generación de credenciales (Cuentas de Servicio) está restringida exclusivamente al Rol de Administrador de Organización (Org Admin). Un usuario estándar o desarrollador no tiene privilegios para crear o gestionar estas credenciales.

Origen de la Identidad: El inicio de sesión del Administrador para realizar cualquier configuración se realiza obligatoriamente a través del SSO de Citi (SAML), asegurando que la identidad proviene de una fuente federada y confiable.

Existen dos mecanismos para autenticar la integración (ambos soportados):

Snyk API Token (Opción A):

Mecanismo de Autenticación: Se basa en una API Key.

Naturaleza: Es un secreto compartido estático de alta entropía (generado con librerías OpenSSL estándar).

Rotación: Programática (vía API).

OAuth 2.0 (Opción B - Recomendada):

Mecanismo de Autenticación: Se basa en Client ID y Client Secret.

Naturaleza: Intercambio de credenciales por un JWT (JSON Web Token) dinámico y efímero.

Rotación: Automática (el token expira cada 60 minutos).

2. Flujo de Integración y Ciclo de Vida (Paso a Paso)

A continuación, se detalla el ciclo de vida completo de la autenticación, desde el inicio de sesión del administrador hasta el cierre de la conexión:

Inicio de Sesión Administrativo: El usuario con rol de Administrador accede a la plataforma de Snyk autenticándose mediante Citi SSO (Single Sign-On).

Validación de Roles: La plataforma valida que el usuario posea el rol de Organization Admin. Si no cuenta con este rol, no se habilita el acceso a la configuración de "Service Accounts".

Creación de Cuenta de Servicio: El administrador navega a Settings > Service Accounts y crea una nueva cuenta de servicio específica para el pipeline de CI/CD, aislando la identidad de la máquina de la identidad del usuario humano.

Generación de Credenciales (Selección de Mecanismo):

Si se elige API Token: Snyk genera una API Key única (Token estático).

Si se elige OAuth 2.0: Snyk genera un par de Client ID y Client Secret.

Almacenamiento Seguro: El administrador copia las credenciales generadas y las almacena inmediatamente en GitHub Secrets a nivel de organización o repositorio. Snyk no vuelve a mostrar el secreto completo tras este paso.

Ejecución del Pipeline (Workflow Trigger): Un desarrollador realiza un push de código, lo que detona el runner de GitHub Actions.

Inyección de Secretos: GitHub Actions inyecta las credenciales almacenadas en el entorno seguro del runner efímero.

Autenticación y Escaneo (Uso):

Caso API Token: El Snyk CLI utiliza la API Key para firmar las peticiones (HMAC) hacia la API de Snyk.

Caso OAuth: El Snyk CLI envía el Client ID y Client Secret al endpoint de OAuth; Snyk responde con un Access Token (JWT) válido por 1 hora. Este JWT se usa como Bearer Token para el escaneo.

Protección de Transporte: Todas las comunicaciones se realizan obligatoriamente sobre TLS 1.2 o 1.3 cifrado.

Finalización y Expiración:

Al terminar el job de GitHub, el runner se destruye, eliminando las credenciales de la memoria.

En el caso de OAuth, el JWT expira automáticamente a los 60 minutos.

Si la sesión de GitHub o Snyk se cierra o invalida, las credenciales dejan de tener efecto en el contexto de esa ejecución.

Controles Compensatorios (mTLS y WAF)

Dado que es una solución SaaS Multi-tenant que no utiliza mTLS ni túneles VPN/VPC, la seguridad se garantiza mediante:

Cifrado: Uso estricto de TLS 1.2/1.3 (equivalente a la seguridad de un túnel).

Autenticación de Aplicación: La seguridad reside en la robustez del Token/OAuth (Identidad) y no en la red.

Protección WAF (Akamai): El WAF perimetral filtra y rechaza cualquier petición que no contenga un token de autorización válido, protegiendo los endpoints antes de que toquen la aplicación.

Quedamos atentos a tu confirmación para proceder con el cierre del hallazgo en la herramienta.

Atentamente,

Flor Ivett Soto / Jose David Santander
Equipo de Integración Técnica Snyk