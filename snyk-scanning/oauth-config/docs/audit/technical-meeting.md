### 1\. Full Verbatim-Style Transcription

**Date:** December 9, 2025
**Platform:** Zoom
**Participants:**

  * **Alex (Banamex Auditor):** Lead Security Auditor/SASA.
  * **Colin (Snyk ISO):** Snyk Technical Engineer/Information Security Officer.
  * **Javier (Banamex):** Meeting facilitator.
  * **Floor (Snyk):** Account/Compliance Manager.

**(00:00 - 00:43) [Introductions and Name Clarification]**
**(00:43) [Topic Start: Snyk Token Architecture]**

**Alex (Banamex Auditor):** So Colin, I was talking with Floor about the CSMQ and compliance questionnaire for your SaaS service, and I have some doubts about the Snyk token. I really like to comprehend the nature of the token—how it's generated, if it's a process of authentication and authorization by GitHub, and if it's going to be like a long-standing token that doesn't have temporary access, or how internally in Snyk you handle the token and all the life of the token.

**Colin (Snyk ISO):** Yeah, excellent question. I'm happy to describe... there are a couple of bits on this diagram that I'll have to go off and check, but I'll describe the bits that I know. And then if you want to know anything else, I'm very happy to take an action, follow up, and then we can have another call. Is that okay?

**Alex (Banamex Auditor):** Sure.

**Colin (Snyk ISO):** So, would you like me to start on the GitHub App token and how that works?

**Alex (Banamex Auditor):** Yeah, please.

**(01:52) [Topic: GitHub App Token & Public Key Infrastructure]**

**Colin (Snyk ISO):** So, as you know, we register an application with GitHub. That's an application in our multi-tenant environment that can be used by anybody. In a single-tenant environment, it's something we set up for you. So it's effectively a token... it's a registration per deployment. So for you, it would be your own registration. As part of that process, a private/public key pair is generated.

**Alex (Banamex Auditor):** Oh.

**Colin (Snyk ISO):** And the public key part of that... and generated with the standard OpenSSL libraries, high entropy source, all of the rest of it. I think it's a 2048-bit key, it might be 4096, I'll have to check. But basically, a private/public key pair is generated for us, and the public key is registered with GitHub as the thing that allows us to prove we are Snyk when we want to use the interfaces to authenticate to GitHub.

**(03:06) [Topic: Authentication Flow & Key Storage]**

**Colin (Snyk ISO):** And then, each time we want to use... and that is set up with our account, multi-factor authentication, passwords, user IDs, all the standard stuff. There's an administrator account that we have with GitHub for Snyk. We register the public key as the one that is going to be used to prove we are Snyk when we want to use the GitHub App interface. And then, when our applications inside the deployment wish to talk to GitHub, they generate the text of a JWT (JSON Web Token), and then the text of the JWT is signed with the private key corresponding to the public/public key pair that we registered when the deployment was set up.

**(04:02) [Topic: Token Lifecycle]**

**Colin (Snyk ISO):** So the token life... the token life is very short. I think if I remember correctly, it's per session request... it's definitely not a long-standing token. It might be a token that lasts five minutes and then we renew it. But essentially, the tokens are dynamically generated and signed with the private key that we registered the public key part with GitHub.

**(04:30) [Topic: Key Rotation Policy]**

**Colin (Snyk ISO):** And then we obviously have a policy of rotating those keys periodically, just for general security purposes. I think it's a yearly rotation. Because obviously, the key is not exposed, so the risk is relatively low, but just good practice is we would rotate those keys on a regular basis to make sure that even if the key had leaked, that would be secure. The key itself, the private key, is stored... I think you're going to be in an AWS deployment... the private key will be stored in the AWS KMS (Key Management Service). So it's only exposed to our code for signing operations. So the key itself isn't lying around, it's in the KMS. So pretty standard practice. But the main thing is the actual tokens that provide the authentication on individual API requests, they are dynamically generated. There is no long-term token. It's proper public key cryptography where we sign the token with the private key to prove who we are. Is that okay?

**Alex (Banamex Auditor):** Yeah. Do you sign it with your JWS and you encrypt with the JWE for generating the token?

**Colin (Snyk ISO):** Yeah, exactly. It's standard... to my mind, it's standard good practice for how you do it.

**(05:58) [Topic: Legacy Authentication Methods]**

**Colin (Snyk ISO):** There is an earlier... not the application interface, but some of our initial deployments going back a couple of years... before the App interface became a common one, there were instances where either the customer gave us user ID and password—that was a very first integration which I think might have been four or five years ago—and then some customers for various reasons still use PAT (Personal Access Tokens). And obviously, [if you] give us a long token used to generate an HMAC on a similar request for validation. But the interface that we recommend and the one we prefer in terms of security is the App interface.

**(07:15) [Topic: Key Rotation Specifics]**

**Alex (Banamex Auditor):** And actually you answered one of my questions regarding the key rotation. That's gonna be one of the important things in the CSMQ.

**Colin (Snyk ISO):** Yeah. And GitHub allow us, if I recall, something like 30 public keys that can be registered at once. So the rotation is a relatively simple procedure, but it's safe because we don't have to remove the previous key immediately. We can put in place the new key, validate that that all works, run it for a period of time before we retire the old key.

**(08:57) [Topic: The "Viewer Snyk Token" (Diagram Item \#11)]**

**Alex (Banamex Auditor):** Okay. Just about the Viewer Snyk Token, that is the connection between GitHub Actions and Snyk. That specific connection.

**Colin (Snyk ISO):** Is that connection 11 on the diagram?

**Alex (Banamex Auditor):** Yeah.

**Colin (Snyk ISO):** I cannot tell you off the top of my head how that one works. I am very happy to go away and find out and then either follow up in email or have another call. I believe that's a dynamically generated token as well, but I will go and check and let you know via email.

**(09:50) [Topic: Infrastructure/Endpoint Security & mTLS]**

**Alex (Banamex Auditor):** Okay. Because I know here it's going to be the SAML for the environment generated by the Single Sign-On. I comprehend this is going to be JWT. But I really don't know this connection... this token.

**(11:00) [Topic: Lack of mTLS & Endpoint Protection]**

**Alex (Banamex Auditor):** I'm mostly concerned about the authentication methods because I see you are not using Mutual TLS. And I comprehend it because it's a multi-tenant application and you are not going to generate certificates for every single one of your clients. But I want to see logically, and by your APIs, how do you authenticate and segregate between your own clients?

**Colin (Snyk ISO):** Yes, we do.

**Alex (Banamex Auditor):** For your endpoint security, talking about infrastructure authentication. I comprehend you don't use the Mutual TLS... but how do you protect the endpoints for being consumed for other entities or any other host attackers that try to connect to those endpoints?

**Colin (Snyk ISO):** Excellent question. Each of the APIs support a number of different authentication mechanisms. From memory, we support OAuth, there may also be a PAT token option. Essentially all of the endpoints have one or more authentication mechanisms that follow standard practice.

**(12:30) [Topic: VPCs/VPNs vs. Public TLS]**

**Alex (Banamex Auditor):** Do you have here any VPCs that segregate the access by filtering IPs?

**Colin (Snyk ISO):** We don't generally support VPCs or VPNs. Taking the view that those technologies generally provide you with an encrypted pipe, but as long as the connection that we actually establish for the API is TLS—which it will be—and as long as we have established good authentication on that... then generally the feeling is we don't need the extra operational complexity of an additional tunnel.

**Alex (Banamex Auditor):** Okay.

**Colin (Snyk ISO):** Moving away from something where you're passing a plaintext password... for those systems, the tunnels are really important. When you've ended up with a system where you're doing TLS... and everything is strongly encrypted, then the general feeling has been that the additional complexity of tunnels... is not something generally felt necessary.

**(15:30) [Topic: Resolution & Next Steps]**

**Alex (Banamex Auditor):** Okay. So what we can do... I close the questionnaire as if it were a non-compliance. We start advancing our process, and the moment you want to share [the diagram/token info], at that moment I take it as evidence and it's over.

**Javier:** Perfect.

**Colin (Snyk ISO):** I will get onto that and aim to give you something early next week. Is it possible to have a copy of this diagram via email?

**Floor:** Yes, I will send it to you today, Colin.

**Alex (Banamex Auditor):** Thank you very much for your time.

**(16:00) [End of Call]**

-----

### 2\. Detailed Fault & Remediation Log (Chronological)

| Time | Specific Fault / Concern | Banamex Requirement / Risk | Snyk Technical Defense / Explanation | Resolution / Outcome |
| :--- | :--- | :--- | :--- | :--- |
| **00:43** | **Snyk Token Lifecycle & Nature** | Auditor queried if tokens are long-standing (static) or temporary, and how they are authenticated. | **Architecture:** Uses GitHub App interface. Private/Public key pair generated (OpenSSL, 2048/4096-bit). Public key registered with GitHub. <br>**Defense:** Tokens are **dynamically generated JWTs** (JSON Web Tokens) signed via private key stored in **AWS KMS**. Token lifespan is per-session/short (approx 5 mins). | **Accepted.** Explanation of dynamic JWT generation signed by KMS-stored private keys satisfied the auditor regarding the GitHub App Token. |
| **07:15** | **Key Rotation Policy** | Requirement for periodic rotation of cryptographic keys to minimize risk of leakage. | **Defense:** Snyk supports multiple active public keys (up to \~30) on GitHub. Policy is **yearly rotation**. The rotation process allows overlap (new key added, validated, then old key retired) to prevent outages. | **Accepted.** The overlap capability and yearly policy were deemed sufficient. |
| **08:57** | **"Viewer Snyk Token" (Connection \#11)** | Unknown authentication method for the specific connection between GitHub Actions and Snyk (item \#11 on provided diagram). | **Defense:** Engineer believes it is dynamically generated but could not confirm "off the top of his head." | **Open Action Item.** Snyk (Colin) must research this specific token type and confirm via email if it is dynamic/secure. |
| **11:00** | **Lack of Mutual TLS (mTLS)** | Auditor noted the absence of mTLS 1.3 for infrastructure-level authentication between client and Snyk endpoints. | **Defense:** Snyk acknowledges lack of mTLS due to multi-tenant complexity (cert management per client). They rely on **Standard TLS (1.2/1.3)** for the pipe + **Strong Application Layer Authentication** (OAuth, PATs, JWT). | **Accepted as Risk Exception.** Auditor accepted the logic ("I comprehend... you are not going to generate certificates for every single client") provided application-level segregation is proven. |
| **12:30** | **Lack of VPC/VPN/IP Filtering** | Inquiry on whether endpoints are segregated via VPCs or IP allow-listing to prevent unauthorized access. | **Defense:** Snyk does **not support VPCs/VPNs** for public interfaces. Argument: Modern security relies on **Strong Encryption (TLS)** + **Identity (OAuth/JWT)** rather than network tunnels ("encrypted pipes"), which add operational complexity without significant added value over TLS. | **Accepted.** Auditor accepted the "Modern Auth \> Tunneling" defense, pending the list of supported auth mechanisms. |
| **15:30** | **Compliance Questionnaire Status** | Current questionnaire cannot be passed without the evidence of the "Viewer Token" and the architecture diagram. | **Defense:** N/A. Process agreement. | **Process Agreement.** Auditor will close the current questionnaire as "Non-compliant/Incomplete" to advance the workflow, pending the arrival of the diagram and token info, which will then clear the block. |

-----

### 3\. Technical Configuration & Architecture Extraction

**Cryptography & Keys**

  * **Token Format:** JWT (JSON Web Token), JWS (JSON Web Signature), JWE (JSON Web Encryption).
  * **Key Generation:** Standard OpenSSL libraries (High entropy source).
  * **Key Specs:** RSA 2048-bit or 4096-bit (To be confirmed by Snyk).
  * **Storage:** AWS KMS (Key Management Service) for private keys.
  * **Rotation:** Yearly rotation policy; supports multiple concurrent keys (approx. 30).

**Authentication Mechanisms**

  * **GitHub App Interface:** Primary method (Dynamic JWTs).
  * **Legacy Methods:** User/Pass (deprecated), PAT (Personal Access Tokens - used for HMAC generation).
  * **SSO:** SAML (referenced by auditor for environment generation).
  * **API Auth:** OAuth, PATs.

**Network & Infrastructure**

  * **Protocol:** TLS (Transport Layer Security) for all API connections.
  * **Cloud Provider:** AWS (Amazon Web Services).
  * **Deployment Model:** Multi-tenant SaaS (Single-tenant logic applied via registration).
  * **Architecture Constraints:** No support for VPC Peering or VPN tunnels for public API consumption. No mTLS enforcement.

**Integrations Mentioned**

  * GitHub Actions (Connection \#11).
  * GitHub Enterprise (Cloud/Enterprise Connection).

-----

### 4\. The "Blocker Removal" Checklist

To convert the status from "Non-Compliant" to "Approved," the following must be delivered:

**Documentation & Evidence (Critical)**

  * [ ] **PDF Architecture Diagram:** Floor (Snyk) must send the specific diagram discussed (showing connection \#11) to Colin and Alex.
  * [ ] **"Viewer Token" Specification:** Colin must research Connection \#11 (GitHub Actions \<-\> Snyk) and confirm via email:
      * Is it dynamically generated?
      * What is the lifespan?
      * Is it a static secret or a signed token?
  * [ ] **Auth Mechanism List:** Colin to provide a definitive list of authentication mechanisms supported by the public APIs (confirming OAuth/PAT support to back up the "No mTLS" defense).

**Technical Fixes**

  * [ ] **N/A:** No code changes or infrastructure patches were requested by Banamex. The approval hinges entirely on the *explanation* and *documentation* of existing controls.