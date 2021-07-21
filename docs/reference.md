# Azure AD Configuration Assessment Reference

# Introduction

This reference describes the checks performed during the Azure Active Directory (Azure AD) Configuration Assessment workshop around the following Identity and Access Management (IAM) areas:

- **Identity Management:** Ability to manage the lifecycle of identities and their entitlements
- **Access Management:** Ability to manage credentials, define authentication experience, delegate assignment, measure usage, and define access policies based on enterprise security posture
- **Governance:** Ability to assess and attest the access granted non-privileged and privileged identities, audit and control changes to the environment
- **Operations:** Optimize the operations Azure Active Directory (Azure AD)

Each category is divided into different checks. Then, each check defines some recommendations as follows:

- **P0:** Implement as soon as possible. This typically indicates a security risk
- **P1:** Implement over the next 30 days. This typically indicates an operational gap
- **P2:** Implement over the next 60 days. This typically indicates optimization in the current operation to make better use of Azure AD provided capabilities
- **P3:** Implement after 60+ days. This is a cleanup, streamlining recommendation.

Each check may contain several forms of results:

- **Summaries:** Notable findings illustrating the current state of the environment being assessed.
- **Recommendations** : Actionable items that improve the alignment of the environment with Microsoft&#39;s best practices.
- **Data Reports** :Reports based on data elements retrieved directly from the environment.

Some checks might not be applicable at the time of the assessment due to customers&#39; environment (e.g. AD FS best practices might not apply if customer uses password hash sync).

Please be aware of the following disclaimers

- The recommendations in this document are current as of the date of this engagement. This changes constantly, and customers should be continuously evaluating their IAM practices as Microsoft products and services evolve over time
- The recommendations are based on the data provided during the interview, and telemetry.
- The recommendations cover several IAM areas, but there is not meant to be taken as of absolute coverage

# Category: Identity Management

## Key Operational Processes

### Check: Owners of Key Tasks

#### Why is this important?

Managing Azure AD requires the continuous execution of key operational tasks and processes which are not necessarily mapped to a rollout project. Nonetheless, it is important to establish them for an optimized operation of customer&#39;s environment.

#### Recommendations

| **Where to find the data for this check?**
- Interview questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **..tasks that miss owners** | Assign an owner | P1 |
| **..tasks with owners that are not aligned with the reference below** | Adjust ownership | P2 |

#### Additional Reference

Operationalize process per the suggestions in the table below:

| **Task** | **Microsoft Recommendation** |
| --- | --- |
| **Define process how to create Azure subscriptions** | (Varies by customer) |
| **Decide who gets EMS licenses** | IAM Team |
| **Decide who gets Office 365 Licenses** | Productivity Team |
| **Decide who gets Other Licenses (Dynamics, VSO, etc.)** | Application Owner |
| **Assign Licenses** | IAM Operations Team |
| **Troubleshoot and Remediate license assignment errors** | IAM Operations Team |
| **Provision Identities to Applications in Azure AD** | IAM Operations Team |

#### Learn More

- [Assigning administrator roles in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-assign-admin-roles-azure-portal)
- [Governance in Azure | Microsoft Docs](https://docs.microsoft.com/en-us/azure/security/governance-in-azure)

## On-premises Identity Provisioning

### Check: Patterns of Sync Issues

#### Why is this important?

It is strongly recommended to have a good baseline and understanding of the issues in the on-premises forests that result in synchronization issues to the cloud. While automated tools such as IdFix and Azure AD Connect Health tend to generate high volume of false positives, some of the findings are going to be impactful and cause support incidents.

#### Recommendations

| **Where to find the data for this check?**
- Power BI: Tab &quot;AADCH – Alerts&quot;, &quot;Sync Performance&quot;, and &quot;Sync – Object Count&quot;
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **...sync errors lingering for more than 100 days** | ..cleanup of objects in errors, since those objects might not even be relevant | P3 |

####

#### Learn More

- [Prepare directory attributes for synchronization with Office 365 by using the IdFix tool - Office 365](https://support.office.com/en-us/article/prepare-directory-attributes-for-synchronization-with-office-365-by-using-the-idfix-tool-497593cf-24c6-491c-940b-7c86dcde9de0)
- [Azure AD Connect: Troubleshooting Errors during synchronization | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnect-troubleshoot-sync-errors)

### Check: Azure AD Connect Sync Configuration

#### Why is this important?

**Active Directory Forest Synchronization**

In order to enable all hybrid experiences, device based security posture and integration with Azure AD, it is required synchronize the user account that employees use to login to their desktops.

**Synchronization Scope and Object Filtering**

Removing known buckets of objects that don&#39;t require to be synchronized has several operational benefits:

1. Less objects means less sources of sync errors
2. Less objects means faster sync cycles
3. Less objects means less &quot;garbage&quot; to carry forward from on prem (e.g. pollution of GAL / people picker for service accounts on prem that don&#39;t make sense in the cloud)

Some examples of objects to exclude are:

- Service Accounts that are not used in the context of cloud applications
- If a single human identity has multiple accounts provisioned (e.g. legacy domain migration, Merger / Acquisition left over), only synchronize the one used by the user on a day to day basis (e.g. what he or she uses to log in to his or her computer)
- Groups that are not meant to be used in cloud scenarios (e.g. no used to grant access to resources)
- Users or contacts that represent external identities that are meant to be modernized with Azure AD B2B Collaboration
- Computer Accounts where employees are not meant to access cloud applications from (e.g. Servers)

It is key to reach a balance between reducing the number of objects to synchronize and the complexity in the rules. Generally, a combination between OU/container filtering plus a simple attribute tagging mapping to cloudFiltered is an effective combination.

**Failover / Disaster Recovery**

Azure AD connect plays a key role in the provisioning process. If the Sync Server goes offline for any reason, changes to on-prem will not be updated in the cloud and cause access issues to users. It is important to define a failover strategy that allows administrators to quickly resume synchronization after the sync server goes offline. Such strategies can follow into the following categories:

1. Deploy Azure AD Connect Server(s) in Staging Mode: This allows administrator to &quot;promote&quot; the staging server to production by a simple configuration switch.
2. Use Virtualization: If the Azure AD connect is deployed in a virtual machine (VM), users can leverage their virtualization stack to live migrate or quickly re-deploy the VM and therefore resuming synchronization.

**Stay current**

Azure AD connect is updated on a regular basis. It is strongly recommended to stay current in order to take advantage of the performance improvements, bug fixes, and new capabilities that each new version provides.

**Source Anchor**

Using ms-ds-consistencyguid as the source anchor allows an easier migration of objects across forests and domains, which is a common situation with AD Domain consolidation/cleanup, mergers, acquisitions, and divestitures.

**Custom Rules**

Azure AD Connect custom rules provide the ability to control the flow of attributes between on-premises objects and cloud objects. When misused/overused, you introduce the following risks:

1. Troubleshooting complexity
2. Degradation of performance when performing complex operations across many objects
3. Higher probability of divergence of configuration between production and staging server
4. Additional overhead when upgrading Azure AD Connect, if custom rules are created within the precedence greater than 100 (used by built-in rules)

Typical patterns of misuse of custom rule include:

- Compensate for dirty data in the directory: In this case, it is recommended to work with the owners of the AD team and clean up the data in the directory as a remediation task, and adjust processes to avoid re-introduction of bad data.
- One-off remediation of individual users: It is common to find rules that special case outliers, usually because of an issue with a particular user. (example: if &quot;SamAccountName&quot; equals &quot;jsmith&quot; then … )
- Overcomplicated &quot;CloudFiltering&quot;: While reducing the number of objects is a good practice, there is a tradeoff between the &quot;precision&quot; to zero in every single object with sync rules. If there is complex logic to include/exclude objects beyond the OU filtering, it is recommended to deal with this logic outside of sync and decorate the objects with a simple &quot;cloudFiltered&quot; attribute that can flow with a very simple Sync Rule.

#### Recommendations

| **Where to find the data for this check?**
- Azure AD Config Documenter Output
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **importing too many objects that are not exported to the cloud** | … filtering by OU, or attributes if customer has a lot of objects imported that are not exported | P3 |
| … **no disaster recovery/failover strategy for Sync** | ...deploy Azure AD Connect in Staging Mode | P2 |
| … **mismatch between production and staging configuration** | …re-baseline Azure AD Connect staging mode to match production configuration. This includes software versions and configurations. | P2 |
| … **customer deployed Azure AD connect but there is no process to compare changes between staging and production** | …operationalize [Azure AD Config Documenter](https://github.com/Microsoft/AADConnectConfigDocumenter) to get details of your sync servers and compare between different sync servers | P3 |
| … **Azure AD Connect version is more than 6 months behind** | … plan to upgrade to the most recent version of Azure AD Connect and | P2 |
| … **source anchor is ObjectGuid** | …Use ms-ds-ConsistencyGuid as source anchor | P3 |
| … **custom rules with precedence value over 100** | …fix the rules so it is not at risk or conflict with the default set | P2 |
| … **overly complex rules** | …Investigate reasons for complexity and identify simplification opportunities | P3 |
| … **Group Filtering is used in Production** | …Transition to another filtering approach | P2 |
| … **Forest being synchronized is NOT the same one users log in their devices** | …Remediate the synchronization to come from the proper forests | P2 |

#### Learn More

[Azure AD Connect sync: Configure filtering | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnectsync-configure-filtering)

[Azure AD Connect: Design concepts | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnect-design-concepts)

[Microsoft/AADConnectConfigDocumenter: AAD Connect configuration documenter is a tool to generate documentation of an AAD Connect installation.](https://github.com/Microsoft/AADConnectConfigDocumenter)

## Entitlement Management

### Check: Group Based Licensing for Microsoft Cloud Services

#### Why is this important?

Azure Active Directory streamlines the management of licenses through Group Based Licensing. This way, IAM provides the group infrastructure and delegated the management of those groups to the proper teams in the organizations. There are multiple ways to set up the membership of groups in Azure Active Directory:

- Synchronized from on-premises: Groups can come from on premises directories, which could be a good fit for organizations that have established group management processes that can be extended to assign licenses in office 365
- Attribute-Based / Dynamic: Groups can be created in the cloud based on an expression based on user attributes (example: Department equals &quot;sales&quot;). Azure AD maintains the members of the group, keeping it consistent with the expression defined. Using this kind of group for license assignment enables an attribute-based license assignment, which is a good fit for organizations that have high data quality in their directory
- Delegated Ownership: Groups can be created in the cloud and can be designated owners. This way, you can empower business owners (example: Collaboration team, BI team) to define who should have access

Another aspect of license management is the definition of service plans (components of the license) that should be enabled based on job functions in the organization. Granting access to services plans that are not necessary can result in additional help desk volume (e.g. users see tools in the office portal that they have not been trained for, or should not be using), unnecessary provisioning, or worse, putting your compliance and governance at risk (e.g. provisioning OneDrive for business to individuals that might not be allowed to share content)

Some guidelines to define service plans to users:

- Define &quot;packages&quot; of service plans to be offered to users based on their role (e.g. white-collar worker versus floor worker)
- Create groups by cluster and assign the license with service plan
- Optionally, an attribute can be defined to contain the packages for users

#### Recommendations

| **Where to find the data for this check?**
- Screenshots: &quot;Azure AD Portal&quot; – &quot;Licenses&quot;
- Admin Portal Interview questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Outstanding licensing errors** | … triage and remediate | P1 |
| … **adhoc manual process to assign licenses and assign components to users** | … deploy Group Based Licensing (GBL) | P1 |
| … **standardized but manual process to assign licenses and assign components to users** | … deploy Group Based Licensing (GBL) | P2 |
| …**mature process and tools to assign licenses to users (e.g. MIM / Oracle Access Manager, etc.), but rely on on-premises infrastructure** | … offload assignment from existing tools and deploy GBL, and define a group lifecycle management based on dynamic groups | P3 |
| … **Existing process does not fully cover Joiners/Movers/Leavers consistently** | … define lifecycle management improvements to the process. If GBL is deployed, define a group membership lifecycle | P2 |
| … **GBL is deployed against on-premises groups that lack lifecycle management** | …consider using cloud groups to enable capabilities such as delegated ownership, attribute based dynamic membership, etc. | P3 |
| … **current process does not monitor licensing errors** | … define improvements to the process to discover and address licensing errors | P2 |
| … **Customer has less licenses than users, and there is no monitoring of Assigned versus Available** | …define improvements to monitor licensing assignment | P2 |

#### Learn More

- [What is group-based licensing in Azure Active Directory? | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-licensing-whatis-azure-portal)

### Check: Assignment of Apps with &quot;All users&quot; group

#### Why is this important?

The &quot;All users&quot; group contains both Members and Guests, and resource owners might misunderstand this group to contain only members. As a result, Special consideration should be taken when using this group for application assignment, and grant access to resources such as SharePoint Content, or Azure Resources

#### Recommendations

| **Where to find the data for this check?**
- Screenshots: &quot;Azure AD Portal&quot; – &quot;Group Settings&quot;
- Admin Portal Interview questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **..&quot;All users&quot; enabled, and apps / resources assigned to it and customers did not want guests access** | … fix the entitlements by creating the right groups (e.g. all members) | P1 |
| **..&quot;All users&quot; enabled, not used for grant access to resources** | … double check that operational guidance to use that group to intentionally include members and guests | P2 |

#### Learn More

[Dynamic groups and Azure Active Directory B2B collaboration | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-b2b-dynamic-groups#hardening-the-all-users-dynamic-group)

### Check: App Provisioning

#### Why is this important?

Automated Provisioning to Applications is the best way to create a consistent provisioning, deprovisioning and lifecycle of identities across multiple systems

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **..Provisioning to Apps is ad-hoc** | …implement application provisioning with Azure AD for supported applications…define a consistent pattern for applications that are not yet supported by Azure AD (would depend on what is supported by the apps) | P1 |
| **..Provisioning to Apps is using CSV files, JIT and other that does not address the full lifecycle (e.g.Movers or Leavers)** | …implement application provisioning with Azure AD | P2 |
| …**Provisioning to Apps is automated and consistent across Joiners, Movers and leavers with On-Premises tools (e.g. MIM)** | …simplify application provisioning with Azure AD for supported applications | P3 |
|
 |
 |
 |

#### Learn More

- [Automated SaaS app user provisioning in Azure AD | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/manage-apps/user-provisioning)

### Check: Azure AD Connect Delta Sync Cycle Baseline

#### Why is this important?

It is important to understand the volume of changes in the customer&#39;s organization and make sure that it is not taking too long to have a predictable synchronization time. The default delta sync frequency is 30 minutes.

#### Recommendations

| **Where to find the data for this check?**
- Power BI: Tab &quot;AADCH – Alerts&quot;, &quot;Sync Performance&quot;, and &quot;Sync – Object Count&quot;
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **..delta sync is taking over 30 minutes for 95 percentile** | ..deep dive and review setup against hardware [guidelines](https://aka.ms/aadconnectperf) | P2 |
| **..significant discrepancies between the delta sync performance of staging and production** | ..deep dive and review setup against hardware [guidelines](https://aka.ms/aadconnectperf) | P2 |
| … **full sync cycles that are not needed** | …deep dive understand why | P2 |
| … **consistent volume trend of add/deletes is over 1% and/or updates is over 10%** | … review of what&#39;s causing it, for example a script on prem touching all objects | P3 |

#### Learn More

- [Prepare directory attributes for synchronization with Office 365 by using the IdFix tool - Office 365](https://support.office.com/en-us/article/prepare-directory-attributes-for-synchronization-with-office-365-by-using-the-idfix-tool-497593cf-24c6-491c-940b-7c86dcde9de0)
- [Azure AD Connect: Troubleshooting Errors during synchronization | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnect-troubleshoot-sync-errors)

# Category: Access Management

## Key Operational Processes

### Check: Owners of Key Tasks

#### Why is this important?

Managing Azure AD requires the continuous execution of key operational tasks and processes which are not necessarily mapped to a rollout project. Nonetheless, it is important to establish them for an optimized operation of customer&#39;s environment.

#### Recommendations

| **Where to find the data for this check?**
- Interview questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **..tasks that miss owners** | Assign an owner | P1 |
| **..tasks with owners that are not aligned with the reference below** | Adjust ownership | P2 |

#### Additional Reference

Operationalize process per the suggestions in the table below:

| **Task** | **Microsoft Recommendation** |
| --- | --- |
| **Manage lifecycle of SSO Configuration in Azure AD** | IAM Operations Team |
| **Design Conditional Access Policies for Azure AD Applications** | InfoSec Architecture Team |
| **Archive Sign-In Activity in a SIEM system** | InfoSec Operations Team |
| **Archive Risk Events in a SIEM system** | InfoSec Operations Team |
| **Triage Security Reports** | InfoSec Operations Team |
| **Triage Risk Events** | InfoSec Operations Team |
| **Triage Users Flagged for risk, and Vulnerability reports from Azure AD Identity Protection (P2)** | InfoSec Operations Team |
| **Investigate Security Reports** | InfoSec Operations Team |
| **Investigate Risk Events** | InfoSec Operations Team |
| **Investigate Users Flagged for risk, and Vulnerability reports from Identity Protection (P2)** | InfoSec Operations Team |

#### Learn More

- [Assigning administrator roles in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-assign-admin-roles-azure-portal)
- [Governance in Azure | Microsoft Docs](https://docs.microsoft.com/en-us/azure/security/governance-in-azure)

## Credentials Management

### Check: Password Management

#### Why is this important?

Password Change/Reset is one of the biggest sources of volume and cost of help desk calls. In addition to this, changing the password as a tool to mitigate a user risk is a fundamental tool to improve the security posture in your organization.

#### Recommendations

| **Where to find the data for this check?**
- Interview questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **a help-desk centric or ad-hoc approach to password change** | Deploy Azure AD Self-Service Password Reset (SSPR) and on-premises Password Protection | P2 |
| … **existing self-service password management solution that relies in on-premises product (e.g. MIM)** | Deploy Azure AD Self-Service Password Reset (SSPR) and on-premises Password Protection | P3 |
| … **SSPR is not used in remediation of users at risk AND customer has Azure AD Premium P2** | Deploy SSPR and use it as part of Identity Protection User Risk Policy | P2 |
| … **new employees are handed over a temporary password in paper, email to manager, etc.** | Use SSPR instead of a temporary password | P3 |

#### Learn More

- [Azure AD tiered password security | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-secure-passwords)
- [Azure AD self-service password reset overview | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/authentication/active-directory-passwords-overview)
- [Dynamically banned passwords in Azure AD | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/authentication/concept-password-ban-bad)
- [Deploy Azure AD password protection preview | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/authentication/howto-password-ban-bad-on-premises)

### Check: Password Policy

#### Why is this important?

Managing passwords securely is of the most critical part of the identity system, and oftentimes the biggest target of attacks.

#### Recommendations

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **no mechanism to protect against weak passwords** | … deploy Azure AD SSPR and password protection | P1 |
| … **no mechanism to detect leaked passwords** | … deploy password hash sync (PHS) to gain insights | P1 |
| … **password policy uses complexity-based rules:**
- **Length**
- **Multiple Character Sets**
- **Expiration**
 | …reconsider in favor of Microsoft Recommended Practices and switch to password that are not easy to guess, to either not expire or a long expiration period | P2 |
|
 |
 |
 |
| … **no MFA registration of users at scale** | … register all users for MFA, so it can be used as a mechanism to authenticate in addition to just passsords | P2 |
| … **no revocation of passwords based on user risk and the customer has P2 licenses** | … deploy Identity Protection User Risk Policies | P2 |
| … **no smart lockout mechanism to protect malicious authentication from bad actors coming from identified IP addresses** | … deploy cloud managed authentication with either password hash sync (PHS) or pass-through authentication (PTA).
 | P2 |
| … **customer has AD FS and it is not feasible to move to managed authentication and Extranet Soft Lockout is not deployed, or Smart Lockout is not deployed** | … deploy AD FS extranet soft lockout and / or Smart Lockout | P1 |

#### Learn More

- [https://aka.ms/passwordguidance](https://aka.ms/passwordguidance)
- [Azure AD and AD FS best practices: Defending against password spray attacks – Enterprise Mobility + Security](https://cloudblogs.microsoft.com/enterprisemobility/2018/03/05/azure-ad-and-adfs-best-practices-defending-against-password-spray-attacks/)
- [Azure AD password protection preview | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/authentication/concept-password-ban-bad-on-premises)

### Check: Strong Credential Management

#### Why is this important?

Passwords by themselves are not secure enough to prevent bad actors to get access to your environment. It is key to provision strong credentials to all users to enable multi-factor authentication (MFA) access policies with and self-service password reset using strong credentials.

#### Recommendations

| **Where to find the data for this check?**
- Interview questions
 |
| --- |
| **If you find …** | We recommend … | With this suggested priority … |
| … **not all privileged accounts are registered and using MFA** | … enable MFA for all privileged accounts | P0 |
| **..not all users are registered with MFA** | … Plan to register MFA to all users | P1 |
| **...MFA is not part of authentication policies (e.g. Conditional Access, Per User MFA, IdP on prem MFA) at all** | … Protect user authentication with MFA using Conditional Access | P1 |
| …**MFA is part of authentication policies using per-user MFA (old policies) or on-prem IDP rules** | … Upgrade authentication policies to use Conditional Access | P2 |
| … **users are configured with only kind of MFA credentials** | … Register additional factors for users per guidance on https://aka.ms/resilientaad |
 |

#### Learn More

- [Converged registration for Azure AD SSPR and MFA (public preview) | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/authentication/concept-registration-mfa-sspr-converged)
- [Create a resilient access control management strategy - Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/authentication/concept-resilient-controls)

### Check: On-Prem Outage Authentication Resiliency

#### Why is this important?

Attacks such as non-Petya are known to infect on-premises network very severely. In addition to the benefits of simplicity and enabling leak credential detection, Azure AD Password Hash Sync (PHS) and Azure AD MFA allow users to access SaaS applications and Office 365 despite of on-premises outages.

It is possible to enable PHS, while keeping federation. This allows a fallback of authentication when federation services are not available.

####

#### Recommendations

| **Where to find the data for this check?**
- Interview questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **no on-premises outage resiliency strategy** | Deploy Password Hash Sync and define a disaster recovery plan that includes using PHS for authentication | P1 |
| … **on-premises outage resiliency strategy that is not integrated with Azure AD** | Deploy Password Hash Sync and update disaster recovery plan to leverage PHS | P2 |
| … **authentication choice is different from what is called in aka.ms/auth-options** | Align Authentication with Microsoft Recommendation | P2 |

#### Learn More

[Implement password synchronization with Azure AD Connect sync | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnectsync-implement-password-synchronization)

[Choose the right authentication method for your Azure AD hybrid identity solution | Microsoft Docs](https://docs.microsoft.com/en-us/azure/security/azure-ad-choose-authn)

### Check: Programmatic Usage of Credentials

#### Why is this important?

Azure AD scripts using PowerShell, or applications using Graph API require authentication. Poor credential management executing those scripts and tools increase the risk of credential theft

#### Recommendations

| **Where to find the data for this check?**
- Power BI: Tab &quot;App Keys&quot;
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **there is a known dependency**** client secret and/or passwords flows for scripts or applications** | … move away to use Azure Managed Identities, Windows Integrated Authentication or Certificates whenever possible.For applications where this is not possible, consider using Azure KeyVault... code / config review to discover and remediate passwords in config files or source code | P2 |
| … **there are service principals with password credentials and there is no knowledge about if / how are those password credentials secured by applications or scripts** | … contact application owners and understand usage patterns | P2 |

#### Learn More

- [Get data using the Azure AD Reporting API with certificates | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-reporting-api-with-certificates)

## Authentication Experience

### Check: On-premises authentication

#### Why is this important?

Federated Authentication with windows integrated authentication (WIA) or Seamless SSO managed authentication (PHS/PTA) is the best user experience when inside the corporate network with line of sight to On-premises Domain Controllers. In addition, it reduces cred prompt fatigue thus reducing the risk of users falling for phishing attacks

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **..customer is using cloud managed authentication with PHS or PTA but users need to type in their password when authenticating on-premises** | .. deploy seamless SSO | P1 |
| … **customer is federated, and there are plans to migrate to cloud managed authentication** | … plan to deploy seamless SSO as part of the migration project | P2 |
|
 |
 |
 |

#### Learn More

- [Assigning administrator roles in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-assign-admin-roles-azure-portal)

### Check: Device Trust Access Policies

#### Why is this important?

Authenticating the device and account for its trust type improves your security posture and usability by:

1. Avoid friction (e.g. MFA) when the device is trusted
2. Blocks access from untrusted joined devices

Microsoft Intune can be used to manage the device and enforce compliance policies, attest device health, and set conditional access policies based on whether the device is compliant; Microsoft Intune can manage iOS devices, Mac desktops (Via JAMF integration), Windows desktops (natively using MDM for windows 10, and co-management with System Center Configuration Manager) and Android mobile devices.

Hybrid Azure AD joined can be enabled only to express conditional access policies based on the domain joined status of the device. Device Management and Compliance is enforced and attested outside, typically using Group Policy Objects, System Center Configuration Manager or similar tools.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Domain Joined Windows Devices are not registered in the cloud** | Register the devices to the cloud and use Hybrid Azure AD Join as a control in Conditional Access policies | P2 |
| … **Domain Joined Windows Devices are already registered in the cloud, but are not used in conditional access policies** | Use Hybrid Azure AD Join as a control in Conditional Access policies | P2 |
| … **Customer is managing Windows 10 devices with MDM, but device controls are not used in conditional access policies** | Use Compliant Device as a control in Conditional Access policies | P2 |
| … **Customer is managing mobile devices with Microsoft Intune, but device controls are not used in conditional access policies** | Use Compliant Device as a control in Conditional Access policies | P2 |

#### Learn More

- [How To - Require managed devices for cloud app access with Azure Active Directory conditional access | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/conditional-access/require-managed-devices)
- [Identity and device access configurations - Microsoft 365 Enterprise | Microsoft Docs](https://docs.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-policies-configurations)

### Check: Windows Hello for Business

#### Why is this important?

#### In Windows 10, Windows Hello for Business (WH4B) replaces passwords with strong two-factor authentication on PCs and mobile devices. This enables a more streamlined MFA experience for users, and reduces reliance on passwords

####

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **customer has Windows 10 devices but WH4B is not deployed or partially deployed** | … deploy WH4B to all Windows 10 Devices | P2 |
| … **customer has not started Windows 10 Rollout** | … adjust plan to include WH4B as part of the Windows 10 Rollout project | P2 |

#### Learn More

- [Windows Hello for Business (Windows 10) | Microsoft Docs](https://docs.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/hello-identity-verification)
- [Manage Windows Hello in your organization (Windows 10) | Microsoft Docs](https://docs.microsoft.com/en-us/windows/security/identity-protection/hello-for-business/hello-manage-in-organization)

## Application Authentication and Assignment

### Check: Single Sign-On for apps

#### Why is this important?

Providing a standardized single sign on mechanism to the entire enterprise is crucial for best user experience, reduction of risk, ability to report, and governance.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Applications that support SSO with Azure AD but are configured to use local accounts** | …Re-configure the applications to use SSO with Azure AD | P1 |
| … **Applications that support SSO with Azure AD but are using another Identity Provider** | …Re-configure the applications to use SSO with Azure AD | P2 |
| … **Applications that don&#39;t support federation protocols but support forms authentication** | …Configure the application to use password vaulting with Azure AD | P2 |
| … **Applications that are configured with Azure AD for SSO as custom apps, but gallery exists** | …Configure the application using the app gallery | P3 |
| … **No mechanism to discover ungoverned applications in the environment** | …Define a discovery process (e.g. CASB solution?) | P2 |

#### Learn More

- [What is application access and single sign-on with Azure Active Directory? | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/manage-apps/what-is-single-sign-on)

### Check: Migration of AD FS Applications to Azure AD

#### Why is this important?

Migrating single sign on configuration from AD FS to Azure AD enables additional capabilities on security, a more consistent manageability, and collaboration.

#### Recommendations

| **Where to find the data for this check?**
- Output of AD FS migration tool
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Applications configured in AD FS that support SSO against Azure AD** | …Re-configure the applications to use SSO with Azure AD | P2 |
| … **Applications configured in AD FS using uncommon configurations that are not supported By Azure AD** | …Reach out to application owners to understand if the special configuration is indeed a requirement of the application. If the special configuration is NOT a requirement, Re-configure the applications to use SSO with Azure AD. If the special configuration is a requirement, provide configuration details and scenarios to your Microsoft Representative | P2 |

#### Learn More

- [Migrate AD FS on-premises apps to Azure AD | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/manage-apps/migrate-adfs-apps-to-azure)

### Check: App Assignment

#### Why is this important?

Assigning users to applications is best mapped when using groups, because they allow great flexibility and ability to manage at scale:

1. Attribute based using dynamic group membership
2. Delegation to app owners

#### Recommendations

| **Where to find the data for this check?**
- Power BI: Tab &quot;App Assignments&quot;
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Applications have assignment to individual users, and there is no attestation / governance in place** | …Implement attestation to applications with direct assignments | P2 |
| … **Applications have assignment to groups, and there is no attestation / governance in place for those groups** | …Implement attestation to groups used for application access | P2 |
| … **Applications have assignment to groups, and groups are managed by IT** | …Improve management at scale through one of the mechanisms below, whenever it is applicable:\* delegating group management and governance to application owners, \* allowing self-service access to the application \* define dynamic groups if user attributes can consistently determine access to applications | P2 |

#### Learn More

- [How to assign users and groups to an application | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/application-access-assignment-how-to-add-assignment)

## Access Policies

### Check: Trusted Networks

#### Why is this important?

Trusted networks enable the following scenarios:

1. Create Conditional Access Policies based on network. While federated customers can leverage &quot;insideCorporateNetwork&quot; claim, there are flows like refresh token that requires re-computation of CA policies when IP Address changes.
2. Risk events based on IP Address such as impossible travel and unfamiliar locations. Not having the trusted network list will result in false positives in Azure AD Identity Protection risk events (This requires Azure AD Premium P2 Licenses)

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **..customer uses PHS/PTA and there are no trusted networks defined** | …define trusted networks to improve detection of risk events | P1 |
| … **customer is federated and does not use &quot;insideCorporateNetwork&quot; claim and there are no trusted networks defined** | …define trusted networks to enable detection of risk events | P1 |
| … **customer is federated uses the &quot;insideCorporateNetwork&quot; claim but there are no trusted networks defined** | …define trusted networks to improve detection of risk events | P2 |
| … **customer does not use trusted networks in conditional access policies, and there is no risk or device controls in conditional access policies either** | … design the conditional access to include network locations | P1 |
| **..the customer still using trusted IPs within MFA old config rather than Named Networks and marking them as trusted** | ….define Named Networks and mark them as trusted to improve detection of risk events | P2 |

#### Learn More

- [Configure named locations in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-named-locations)

### Check: Risk-Based Access Policies (If applicable)

#### Why is this important?

Azure AD calculates risk for every sign in and every user. Using this risk as a criteria in access policies can provide a better user experience (e.g. fewer authentication prompts), better security (only prompt users when they are needed, and moreover automate the response and remediation).

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Customer has licenses to use risk in access policies, but it is not used** | …add risk to security posture | P2 |

#### Learn More

- [Configure named locations in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-named-locations)

### Check: Client Application Access Policies

#### Why is this important?

Microsoft Intune Application Management (MAM) provides the ability to push data protection controls such as storage encryption, PIN, remote storage cleanup, etc. to compatible client mobile applications such as Outlook. Then, Conditional Access can enforce policies that will restrict access to cloud services (such as Exchange Online) from approved/compatible apps.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **Users install MAM capable applications (e.g. Office Mobile Apps) to access corporate resources (e.g. Email or sharepoint) AND there is desire to allow personal devices** | Deploy application MAM policies to manage the application configuration in personal owned devices without MDM enrollment.Update Conditional Access policies to only allow access from MAM capable clients. | P1 |
| **Users install MAM capable applications (e.g. Office Mobile Apps) against corporate resources and the access is restricted on Intune Managed devices** | Deploy application MAM policies to manage the application configuration and be future proof for personal devices.Update Conditional Access policies to only allow access from MAM capable clients. | P3 |

#### Learn More

- [How to require approved client apps for cloud app access with conditional access in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/conditional-access/app-based-conditional-access)

### Check: Conditional Access Implementation

#### Why is this important?

Conditional Access is an essential tool to enable the security posture of your organization. It is important to follow key practices

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you DO NOT find this …** | **.. we recommend remediation with this priority** |
| --- | --- |
| **Ensure that all SaaS applications will have at least one policy applied** | P1 |
| **Migrate all &quot;legacy&quot; policies to the Azure Portal** | P1 |
| **Customer still has per-user MFA** | P2 |
| **Catch-all criteria for users, devices, and applications** | P1 |
| **Have a small set of core policies that can apply to multiple applications** | P2 |

### Check: Conditional Policy Dashboard

| **If you find …** | **We recommend …** | **With suggested priority …** |
| --- | --- | --- |
| **Proper Exclusion Check** |
| **Policies with No Users or Groups Excluded** | Excluding at least one group from every policy | P1 |
| **Policies with Only Users Excluded** | Putting these users into a group and excluding the group instead | P3 |
| **Policies with Both Users and Groups Excluded** | Adding the excluded users to one of the groups already being excluded OR creating a new group with the excluded users and excluding that group as well | P3 |
| **Proper Inclusion Check** |
| **Policies that Only Include Users** | Putting these users into a group and including this group instead | P3 |
| **Policies that Include Both Users and Groups** | Adding the included users to one of the groups already being included OR creating a new group with the included users and including that group as well | P3 |
| **Break Glass Hygiene Check** |
| **Common Group Being Excluded from Policies AND Common User Being Excluded from Policies** | Making the common user being excluded part of one of the common groups that is being excluded | P3 |
| **No Common Group Being Excluded from Policies, BUT Common User Being Excluded from Policies** | Putting the common user(s) being excluded into a group and excluding this group from every policy instead | P3 |
| **No Common Group OR User being Excluded from Policies** | Creating a group that is excluded from every single CA policy | P1 |
| **Block Legacy Authentication Check** |
| **No Policies that Block Legacy Authentication** | Creating a CA Policy that blocks legacy authentication | P1 |
| **Bad Practice Avoidance Check** |
| **Policies that Block Access for All Users and Cloud Apps** | Reviewing these policies, as they risk locking out the customer&#39;s entire organization | P1 |
| **Policies that Require Compliant Device Access for All Users and Apps** | Reviewing these policies, as they risk locking out users who have not enrolled their devices yet | P1 |
| **Policies that Require Azure AD Hybrid Joined Devices for All Users and Cloud Apps** | Reviewing these policies, as they risk locking out users who don&#39;t yet have domain-joined devices | P1 |
| **Policies that Require App Protection Policy for All Users and Cloud Apps** | Reviewing these policies, as they risk locking out the customer&#39;s entire organization if they do not have an Intune policy | P1 |
| **Policies that Block All Users, Apps, and Device Platforms** | Reviewing these policies, as they risk locking out the customer&#39;s entire organization | P1 |
| **App Lockout Risk Check** |
| **Policies that Block with All Apps Filter** | Reviewing these policies, as they risk locking out the customer&#39;s users | P1 |
| **Guest Coverage Check** |
| **No Policies Explicitly Including Guests** | Creating at least one policy that specifically targets guests | P2 |
| **No Policies Requiring Guest MFA for All Apps** | Creating a policy that applies to guests and requires MFA for all applications | P2 |
| **Policies Requiring Azure AD Hybrid Joined or Compliant Devices for Guests** | Reviewing these policies, as they risk locking out guest users (guests typically do not have Hybrid-Joined or Compliant Devices) | P1 |
| **Policies Using the &quot;All Users&quot; Filter that Impacts Guests (Look for policies listed in the Guest Policy Summary Section that are not listed as Explicit Guest Policies)** | Reviewing these policies to ensure that the customer meant for these policies to impact guests (customers are often unaware that the &quot;All Users&quot; filter includes guests) | P2 |
| **Office 365 Coverage Check** |
| **No Explicit Policies targeting the Office 365 App Group** | Creating at least one policy that specifically targets the Office 365 App Group | P2 |
| **Policies Using Individual Office 365 Apps Instead of the Office 365 App Group** | Using the Office 365 App Group instead of the Individual Office 365 Apps | P2 |
| **Policies that do not have Client MAM for Office 365 Apps** | Adding &quot;Require App Protection Policy&quot; as one of the grant controls for these policies | P2 |
| **Azure Management Coverage Check** |
| **No Policy Explicitly Including the Microsoft Azure Management App** | Creating at least one policy that specifically includes the Microsoft Azure Management App | P2 |
| **Stale Inclusion/Exclusion Check** |
| **Stale Users, Apps or Groups being Included/Excluded from CA Policies** | Having the customer re-save each of these policies in their CA portal. This will trigger the automatic removal of stale users/apps/groups from that specific policy. | P3 |
| **Network Locations Check** |
| **No Named Locations Marked as Trusted** | Having at least one named location that is marked as &quot;Trusted&quot; | P2 |
| **No Policies Blocking Based on Countries AND No Policies Blocking All Besides Certain Countries AND Customer has Parts of the World they don&#39;t do Business with** | Creating a policy that takes advantage of location signals. This can either be done by creating a block policy that targets certain countries OR by creating a policy that blocks all sign-in attempts besides those from a group of trusted countries. | P2 |

#### Learn More

- [Best practices for conditional access in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-conditional-access-best-practices)
- [Identity and device access configurations - Microsoft 365 Enterprise | Microsoft Docs](https://docs.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-policies-configurations)
- [Azure Active Directory conditional access settings reference | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/conditional-access/technical-reference)

## Access Surface Area

### Check: Legacy Authentication

#### Why is this important?

Legacy Authentication protocols can&#39;t be protected with strong credentials, and it is the preferred attack vector by malicious actors. Locking down legacy authentication is crucial to improve the access security posture.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

####

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Legacy Authentication is widely used in the environment** | .. plan to migrate legacy clients to modern auth capable clients | P0 |
| … **Some users are already using Modern authentication, but there are still accounts that use legacy authentication** | … roll out controls to contain footprint of legacy auth, per the steps in &quot;Reference&quot; section below | P0 |
| … **Legacy Authentication is not locked down at the source** | … roll out controls to disable legacy authentication protocols in Exchange and other target services | P1 |
|
 |
 |
 |

#### Reference

Steps to lock down legacy authentication:

1. Use Sign In Activity reports to identify users who are still using legacy authentication and plan remediation:
  1. Upgrade to modern authentication capable clients to affected users
  2. Plan a cutover timeframe to lock down per steps below
  3. Identify what legacy applications have a hard dependency on legacy authentication. See step 3 below.
2. Disable legacy protocols at the source (e.g. Exchange Mailbox) for users who are NOT using legacy auth to avoid additional exposure
3. For the remaining accounts (ideally non-human identities such as service accounts), use conditional access to restrict legacy protocols post-authentication

Learn More

[Azure AD Conditional Access support for blocking legacy auth is in Public Preview! - Microsoft Tech Community - 245417](https://techcommunity.microsoft.com/t5/Azure-Active-Directory-Identity/Azure-AD-Conditional-Access-support-for-blocking-legacy-auth-is/ba-p/245417)

[Enable or disable POP3 or IMAP4 access to mailboxes in Exchange Server | Microsoft Docs](https://docs.microsoft.com/en-us/exchange/clients/pop3-and-imap4/configure-mailbox-access?view=exchserver-2019)

[How modern authentication works for Office 2013 and Office 2016 client apps | Microsoft Docs](https://docs.microsoft.com/en-us/office365/enterprise/modern-auth-for-office-2013-and-2016)

### Check: Consent Grants

#### Why is this important?

Users might be granting consent to malicious applications via phishing attack, or voluntarily by not being careful when using malicious websites. Below are some permissions that you might want to scrutinize:

- Application with app or delegated \*.ReadWrite Permissions
- Applications with delegated permissions can read, send, or manage email on behalf of the user
- Applications

#### Recommendations

| **Where to find the data for this check?**
- Power BI: Tab &quot;Consent Grant&quot;
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Applications with illicit grants** | Remove the grants | P1 |
| … **Applications that have more grants than needed** | Remove additional grants | P2 |
| … **No procedures to detect and prevent illicit or excessive grants** | Set regular reviews of app permissions and remove when not needed, and/or remove self-service altogether and establish governance procedures | P2 |
|
 |
 |
 |

#### Learn More

[Detect and Remediate Illicit Consent Grants in Office 365 | Microsoft Docs](https://docs.microsoft.com/en-us/office365/securitycompliance/detect-and-remediate-illicit-consent-grants)

[Azure Active Directory (AD) Graph API Permission Scopes](https://msdn.microsoft.com/en-us/library/azure/ad/graph/howto/azure-ad-graph-api-permission-scopes)

### Check: User and Group Settings

#### Why is this important?

Below are some user and group settings that can be locked down if there is not an explicit business need:

**User Settings**

- **External Users:** External collaboration can happen organically in the enterprise with services like Teams, PowerBI, Sharepoint Online, and Azure Information Protection.

If customer has explicit constrains to block user-initiated external collaboration, is recommended to disable it and revisit them once external identities are ready to be enabled back. Alternatively, customers can decide to enable external users through as a controlled operation (e.g. supporting help desk ticket).

- **App Registrations:** When App registrations are enabled, end users can self-service onboard applications and grant access to user&#39;s data. A typical example of this registration is users enabling outlook plugins, or voice assistants such as Alexa and Siri to read their email and calendar or send emails on their behalf.

If the customer decides to turn this off, the Infosec and IAM teams must be involved in the management of exceptions (app registrations that are needed based on), as they would need to register the applications with an admin account, and most likely require designing a process to operationalize this.

- **Administration Portal:** Azure Portal can be locked down so that non-administrators can&#39;t log in the Azure AD management portal

**Group Settings:**

- **Self-Service Group Management/Users can create Security groups/O365 groups:** If there is no current self-service initiative for groups in the cloud, customers might decide to turn it off until they are ready to use this capability.

#### Recommendations

| **Where to find the data for this check?**
- Screenshots: &quot;Azure AD Portal&quot; – &quot;User Settings&quot; - &quot;Enterprise Applications&quot;
- Screenshots: &quot;Azure AD Portal&quot; – &quot;User Settings&quot; - &quot;External Collaboration&quot;
- Screenshots: &quot;Azure AD Portal&quot; – &quot;Group Settings&quot;
- Admin Portal Interview Questions - screenshot sections above
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **...External user settings are not matching target requirements** | Adjust configuration | P2 |
| **...App Registrations settings are not matching target requirements** | Adjust configuration | P2 |
| **...Administration Portal settings are not matching target requirements** | Adjust configuration. If customers don&#39;t want to enable Azure Portal access to avoid user confusion and help desk call. It is worthwhile call out that access to Azure through CLI or other programmatic interfaces will work. | P3 |
| … **Group Settings are not matching target requirements** | Adjust configuration | P2 |

#### Learn More

- [What is Azure Active Directory B2B collaboration? | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-b2b-what-is-azure-ad-b2b)
- [Integrating Applications with Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-integrating-applications)
- [Apps, permissions, and consent in Azure Active Directory. | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-apps-permissions-consent)
- [Use groups to manage access to resources in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-manage-groups)
- [Setting up self-service application access management in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-accessmanagement-self-service-group-management)

### Check: Traffic from unexpected locations

#### Why is this important?

Attackers come from different parts of the world. Manage this risk by blocking countries/regions that customers definitively do not have business with.

#### Recommendations

| **Where to find the data for this check?**
- Screenshots: &quot;Azure AD Portal&quot; – &quot;Security&quot; - &quot;Named Locations&quot;
- Admin Portal Interview Questions
- Interview Questions
 |
| --- |

####

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **.. Ni SIEM tool -or- it is not ingesting authentication information from Azure AD** | ..deploy integration with Azure Monitor, or other SIEM system to identify patterns of access across regions | P2 |
| **..A SIEM tool is deployed, and it is ingesting sign in activity but has not been analyzed** | Use SIEM system to identify patterns of access across regions | P2 |
| **...profile of traffic across region has been identified, but traffic is not locked down** | Use conditional access to block access for location there is no business reason to sign in from | P2 |

Learn More

[Location conditions in Azure Active Directory conditional access | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-conditional-access-locations)

## Access Usage

### Check: Azure AD Logs Archived and integrated with Supportability Incident Response Plans

#### Why is this important?

Having access to Sign In activity, Audits and Risk Events for Azure AD is crucial for troubleshooting, usage analytics, and forensics investigations. Azure AD provides access to these sources through REST APIs and have a limited retention period. A SIEM system, or equivalent archival technology would be key for long term storage of audits and supportability .

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **No long term storage for Azure AD Logs is used** | Enable long term storage of Azure AD Logs by either:
- Add to existing SIEM solution if there is one
- Use Azure Monitor
 | P1 |
| … **Azure AD Logs are archived but not being used as part of incident response plans** | Incorporate Azure AD and O365 Log investigation in incident response plan | P1 |

#### Learn More

- [Azure Active Directory audit API reference | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-reporting-api-audit-reference)
- [Azure Active Directory sign-in activity report API reference | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-reporting-api-sign-in-activity-reference)
- [Get data using the Azure AD Reporting API with certificates | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-reporting-api-with-certificates)
- [Microsoft Graph for Azure Active Directory Identity Protection | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-identityprotection-graph-getting-started)
- [Office 365 Management Activity API reference | MSDN](https://msdn.microsoft.com/en-us/office-365/office-365-management-activity-api-reference)
- [Azure Active Directory activity logs in Azure Monitor (preview) | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/reports-monitoring/overview-activity-logs-in-azure-monitor)

# Category: Governance

## Key Operational Processes

### Check: Owners of Key Tasks

#### Why is this important?

Managing Azure AD requires the continuous execution of key operational tasks and processes which are not necessarily mapped to a rollout project. Nonetheless, it is important to establish them for an optimized operation of customer&#39;s environment.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **..tasks that miss owners** | Assign an owner | P1 |
| **..tasks with owners that are not aligned with the reference below** | Adjust ownership | P2 |

#### Additional Reference

Operationalize process per the suggestions in the table below:

| **Task** | **Microsoft Recommendation** |
| --- | --- |
| **Archive Azure AD Audit Logs in SIEM system** | InfoSec Operations Team |
| **Discover applications that are managed out of compliance** | IAM Operations Team |
| **Regularly reviews access to applications** | InfoSec Architecture Team |
| **Regularly reviews access of external identities** | InfoSec Architecture Team |
| **Regularly reviews who has privileged roles** | InfoSec Architecture Team |
| **Defines security gates to activate privileged roles** | InfoSec Architecture Team |
| **Regularly reviews Consent Grants** | InfoSec Architecture Team |

#### Learn More

- [Assigning administrator roles in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-assign-admin-roles-azure-portal)
- [Governance in Azure | Microsoft Docs](https://docs.microsoft.com/en-us/azure/security/governance-in-azure)

### Check: Config Changes Testing

#### Why is this important?

There are changes that require special considerations when testing, from simple techniques such as rolling out a target subset of users, to deploy a change in a parallel test tenant.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **customer does not have a testing strategy** | …define a test approach based on guidelines below | P2 |

#### Additional Reference

The table below provides some suggestions on test strategies for typical scenarios:

| **Kind of Change** | **Recommended Testing Approach** |
| --- | --- |
| **Change Authentication Type (from federated to password hash sync /pass through authentication and vice versa)** | Test Domain in the same tenant. Create accounts in the test domain |
| **Roll out a new CA policy or Identity Protection Policy** | Create a new CA Policy, assign to test users |
| **Onboard a test environment of an Application** | Add it to a production environment, hide it from My Apps panel, and assign to test users during QA phase |
| **Change of Sync Rules** | Do the changes in a test Azure AD Connect with the same configuration that is currently in production and analyze CSExport Results. If satisfied, swap to prod if / when ready. |
| **Change of Branding** | Test in a separate test tenant |
| **Roll Out a new Feature** | If the feature supports roll out to a target set of users, identify pilot users and build out |
| **Cut Over Application from on premises Identity provider (IdP) to Azure AD** | If the app supports multiple IdP configurations (e.g. Salesforce), configure both and test Azure AD during a change window (in case the application introduces HRD page)If the App does not support multiple IdP, schedule the testing during change control window and program downtime |
| **Update Dynamic Group Rules** | Create a parallel dynamic group with the new rule. Compare against the calculated outcome (e.g. Run PowerShell with the same condition). If test pass, swap the places where the old group was used (if feasible) |
| **Migrate product licenses** | Follow steps[https://docs.microsoft.com/en-us/azure/active-directory/active-directory-licensing-group-product-migration](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-licensing-group-product-migration) from [How to safely migrate users between product licenses by using group-based licensing in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-licensing-group-product-migration) |
| **Change AD FS Rules (Authorization, Issuance, MFA)** | Use group claim to target subset of users |
| **Change AD FS Authentication Experience or similar farm-wide changes** | Create a parallel farm with same host name, implement config changes, test from clients using HOSTS file, NLB routing rules or similar routing.If the target platform does not support HOSTS files (e.g. mobile devices), control change |

#### Learn More

N/A

## Access Reviews

### Check: Access Reviews to Applications

#### Why is this important?

Sometimes user accumulate access to resources as they move throughout different teams/positions over time. It is important to review the access to applications on a regular basis to remove entitlements that are no longer needed throughout the lifecycle of users

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **No process or ad-hoc access reviews of applications access** | Establish a regular access review process for applications. If there is proper licensing in the tenant, consider using Azure AD Access Reviews | P2 |
| … **There is a process, but it is not automated** | If there is proper licensing in the tenant, consider using Azure AD Access Reviews | P3 |
| … **There is a process but it is on-premises** | If there is proper licensing in the tenant, consider using Azure AD Access Reviews | P3 |

#### Learn More

- [Azure AD access reviews | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-azure-ad-controls-access-reviews-overview)

### Check: Access Reviews to External Identities

#### Why is this important?

It is crucial to keep access to external identities constrained only to resources that are needed, during the time that is needed. Periodic access reviews for external identities is key to achieve this.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **No process or ad-hoc access reviews of applications access**** -or- **…** Process no cover all kinds of external identities** | Establish a regular access review process for all kinds of external external identities. If there is proper licensing in the tenant, consider using Azure AD Access Reviews | P2 |
| … **There is a process, but it is not automated or not run periodically** | If there is proper licensing in the tenant, consider using Azure AD Access Reviews | P3 |
| … **There is a process but it is on-premises** | If there is proper licensing in the tenant, consider using Azure AD Access Reviews | P3 |

#### Learn More

- [Azure AD access reviews | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-azure-ad-controls-access-reviews-overview)

## Privileged Accounts Management

### Check: Privileged Accounts Usage

#### Why is this important?

Users with privileged roles tend to accumulate over time. It is important to clean them up and review admin access on a regular basis, as well as to enable a &quot;just in time/ just enough&quot; access to admin roles.

#### Recommendations

| **Where to find the data for this check?**
- Power BI: Tab: &quot;Roles &amp; Notifications&quot;
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Admins have standing access using their day to day accounts** | Deploy PIM (if licenses are available), or consider using separate accounts | P0 |
| … **No security gates/process in place to use privileged accounts** | Define strong authentication to activate privileged roles (either separate admin account with MFA, or deploy PIM (P2 licenses required) | P1 |
| **..No strategy in place to remove unnecessary access of privileged accounts** | Review privileged accounts (e.g. global admins) and assign less privileged roles if applicable. | P1 |
| **..No strategy in place to review access of privileged accounts** | Define Access Reviews for privileged accounts (either automated through PIM or manual process) | P2 |
| … **Strategy to review access in place, but it is not automated or not run regularly** | Define Access Reviews for privileged accounts (either automated through PIM or manual process) | P2 |
| … **Non-human, no emergency access accounts privileged accounts** | Clean up non-human, non-emergency access glass privileged accounts | P2 |

#### Learn More

[Best practices for securing administrative access in Azure AD | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/admin-roles-best-practices)

[Configure Azure AD Privileged Identity Management | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-privileged-identity-management-configure)

[How to perform an access review | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-privileged-identity-management-how-to-perform-security-review)

[Roles in Azure AD Privileged Identity Management | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-privileged-identity-management-roles)

### Check: Emergency Access Accounts

#### Why is this important?

Organizations must provision emergency accounts to be prepared to manage Azure AD for cases such as authentication outages like:

- Outage components of authentication infrastructures (AD FS, On prem AD, MFA service)
- Administrative staff turnover

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **.. No emergency access accounts** | Implement emergency access accounts per [https://aka.ms/breakglass](https://aka.ms/breakglass) | P1 |
| **.. Emergency Access Accounts implementation that is not aligned with Microsoft Best Practices** | Implement emergency access accounts per [https://aka.ms/breakglass](https://aka.ms/breakglass) | P2 |

#### Learn More

[Manage emergency-access administrative accounts in Azure AD | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-admin-manage-emergency-access-accounts)

### Check: Privileged Access to Azure EA Portal

#### Why is this important?

The Azure EA portal allows to create azure subscriptions against a master Enterprise Agreement, which is a very powerful role within the enterprise. It is common to bootstrap the creation of this portal before even getting Azure AD in place, so it is necessary to use Azure AD identities to lock it down, remove personal accounts from the portal, ensure that proper delegation is in place, and mitigate the risk of lockout.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Microsoft Accounts with Privileged Access** | Remove Microsoft Accounts from all privileged access in the EA portal | P1 |
| … **EA Portal Authorization Level is set to&quot;mixed mode&quot;** | Configure EA portal to use Azure AD accounts only | P2 |
| … **EA Portal delegated roles are not fully configured** | Identify and Implement delegated roles for departments and accounts | P3 |

#### Learn More

- [Introduction to Azure Enterprise and Subscription Management – Azure in Education](https://blogs.msdn.microsoft.com/azureedu/2016/10/29/introduction-to-azure-enterprise-and-subscription-management/)
- [https://docs.microsoft.com/en-us/azure/active-directory/active-directory-assign-admin-roles-azure-portal](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-assign-admin-roles-azure-portal)

# Category: Operations

## Key Operational Processes

### Check: Owners of Key Tasks

#### Why is this important?

Managing Azure AD requires the continuous execution of key operational tasks and processes which are not necessarily mapped to a rollout project. Nonetheless, it is important to establish them for an optimized operation of customer&#39;s environment.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **..tasks that miss owners** | Assign an owner | P1 |
| **..tasks with owners that are not aligned with the reference below** | Adjust ownership | P2 |

#### Additional Reference

Operationalize process per the suggestions in the table below:

| **Task** | **Microsoft Recommendation** |
| --- | --- |
| **Drive Improvements on Identity Secure Score** | SecOps team |
| **Maintain Azure AD Connect Servers** | IAM Operations Team |
| **Maintain AD FS Servers and WAP (if applicable)** | IAM Operations Team |
| **Execute and triage IdFix Reports Regularly** | IAM Operations Team |
| **Triage Azure AD Connect Health Alerts for Sync and AD FS** | IAM Operations Team |
| **If not Azure AD Connect, customer has equivalent process and tools for monitor custom infrastructure** | IAM Operations Team |
| **If not AD FS, customer has equivalent process and tools for monitor custom infrastructure** | IAM Operations Team |
| **Monitor Hybrid Logs : Azure AD App Proxy Connectors** | IAM Operations Team |
| **Monitor Hybrid Logs : Passthrough Authentication Agents** | IAM Operations Team |
| **Monitor Hybrid Logs : Password Writeback Service** | IAM Operations Team |
| **Monitor Hybrid Logs : On-premises password protection gateway** | IAM Operations Team |
| **Monitor Hybrid Logs: Azure MFA NPS Extension (if applicable)** | IAM Operations Team |

#### Learn More

- [Assigning administrator roles in Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-assign-admin-roles-azure-portal)
- [Governance in Azure | Microsoft Docs](https://docs.microsoft.com/en-us/azure/security/governance-in-azure)

## Hybrid Management

### Check: Recent versions of On-Premises Components

#### Why is this important?

Having recent versions of on-premises components provides the customer all the latest security updates, performance improvements as well as functionality that could help to further simplify the environment. Components reviewed:

- Azure AD Connect
- Azure AD Application Proxy Connectors
- Azure AD Pass-through authentication agents
- Azure AD Connect Health Agents

Most components have an auto-update setting which will automate the upgrade process.

#### Recommendations

| **Where to find the data for this check?**
- Power BI: Tab &quot;AADCH – Alerts&quot;
 |
| --- |

####


| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| **...No process in place to upgrade hybrid components** | …Define a process to upgrade those components, ideally relying on Auto-Upgrade whenever possible | P2 |
| … **Components that are more than 6 months behind** | …Upgrade components | P2 |

####

#### Learn More

- [Azure AD Connect Health Version History | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect-health/active-directory-aadconnect-health-version-history)
- [Required Updates for Active Directory Federation Services (AD FS) | Microsoft Docs](https://docs.microsoft.com/en-us/windows-server/identity/ad-fs/deployment/updates-for-active-directory-federation-services-ad-fs)

### Check: Azure AD Connect Health Alert Baseline

#### Why is this important?

Azure AD Connect Health must be deployed for monitoring and reporting of Azure AD Connect and AD FS. These are critical components that can break lifecycle management and authentication and therefore lead to outages.

#### Recommendations

| **Where to find the data for this check?**
- Power BI: Tab &quot;AADCH – Alerts&quot;
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Azure AD Connect Health is not deployed for Sync** | … Deploy and enable | P2 |
| … **Azure AD Connect Health is not deployed for AD FS used for federated domains** | … Deploy and enable | P2 |
| … **High Severity Active Alerts** | .. Address High Severity Alerts | P1 |
| … **Lower Severity Active Alerts** | …Address Alerts | P3 |

#### Learn More

- [Monitor your on-premises identity infrastructure in the cloud. | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect-health/active-directory-aadconnect-health)

### Check: On-Premises Agents Logs

#### Why is this important?

Some IAM services require agents on premises to enable hybrid scenarios. Examples include password writeback, pass-through authentication (PTA), Azure AD Application Proxy, and Azure MFA NPS extension. It is key that the operations team baseline the health of the component, and that help desk is equipped to troubleshoot them.

#### Recommendations

| **Where to find the data for this check?**
- Output files generated by tasks 4 and 5
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Patterns of errors in on-premises component logs** | … Investigate and address findings | P2 |
| … **On-Premises Agent Logs are not archived or monitored** | … Archive and Monitor in enterprise monitoring infrastructure (e.g. SCOM / SIEM) | P3 |

#### Learn More

- [Troubleshoot Application Proxy | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-application-proxy-troubleshoot)
- [Self-service password reset troubleshooting- Azure Active Directory | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-passwords-troubleshoot#password-writeback-event-log-error-codes)
- [Understand Azure AD Application Proxy connectors | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/application-proxy-understand-connectors)
- [Azure AD Connect: Troubleshoot Pass-through Authentication | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnect-troubleshoot-pass-through-authentication#collecting-pass-through-authentication-agent-logs)
- [Troubleshoot error codes for the Azure MFA NPS extension | Microsoft Docs](https://docs.microsoft.com/en-us/azure/multi-factor-authentication/multi-factor-authentication-nps-errors)

### Check: On-Premises Agents management

#### Why is this important?

Adopting best practices allows an optimal operation of on-premises agents.

- Multiple Azure AD Application proxy connectors per connector group allows seamless load balancing and high availability by avoiding single points of failure when accessing the proxy applications.
- Using a debug connector group to onboard App proxy applications can help troubleshooting scenarios like Kerberos constrained delegation, discover the entire surface area of the applications, etc. It is also a good idea to have networking tools such as Message Analyzer and Fiddler in the connector machines.
- Multiple pass-through Authentication Agents allow seamless load balancing and high availability by avoiding single point of failure during the authentication flow.

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **Only one App Proxy connector in a connector group that handles production applications** | … Deploy at least two connectors in production connector groups to allow failover | P2 |
| … **Only one Pass-through authentication agent deployed** | … Deploy at least to pass-through authentication agents to allow high availability | P2 |
| … **No Azure AD App Proxy debug connector group deployed** | …Create an app proxy connector group for debugging purposes. This is very useful when onboarding new on-premises application | P3 |
| … **No Debugging tools deployed in debug app proxy connector** | …Deploy debugging tools in app proxy connector in the debug connector group | P3 |

#### Learn More

- [Understand Azure AD Application Proxy connectors | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/application-proxy-understand-connectors)
- [Azure AD Pass-through Authentication - Quick start | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnect-pass-through-authentication-quick-start#step-5-ensure-high-availability)

## Management at Scale

### Check: Identity Secure Score

#### Why is this important?

The Identity Secure Score provides a quantifiable measure of the security posture of your organization. It is key to constantly review and address findings reported and strive to have the highest score possible

#### Recommendations

| **Where to find the data for this check?**
- Screenshots: &quot;Security&quot; – &quot;Identity Security Score&quot;
- Admin Portal Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **No plan/initiative to monitor changes in the Identity Secure Score** | … implement a plan and assign owners to monitor and drive the Improvement Actions | P2 |
| …**Outstanding high score (\&gt;30) Improvement Actions** | .. remediate and plan implementations of Improvement actions | P1 |

#### Learn More

- [What is Identity secure score in Azure AD? - preview | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/identity-secure-score)

### Check: Notifications

#### Why is this important?

Microsoft sends email communications to administrators to notify various changes in the service, configuration updates that are needed, and errors that require admin intervention. It is very important that customers set the notification email addresses, to be sent to the proper team members who can acknowledge and act upon all notifications. Also, customer email infrastructure should be configured to relay email properly.

#### Recommendations

| **Where to find the data for this check?**
- Power BI: Tab &quot;Roles &amp; Notifications&quot;
- Screenshots: &quot;Office Portal&quot; – &quot;Message Center Settings&quot;
- Admin Portal Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| …**Technical Notification is not set to a distribution list (DL) or shared mailbox** | Move technical notification to a DL | P1 |
| … **Office 365 Message Center does not contain a DL or Shared Mailbox** | Add multiple recipients to Office 365 message center | P1 |
| …**Only one global admin has an email address (mail attribute, or alternate email)** | Allow at least two e-mail capable accounts | P1 |
| … **Azure AD Connect Health is not configured DL or Shared Mailbox for alert notification** | Enable Shared Mailbox or a DL for Azure AD Connect Health notifications | P1 |

#### Additional Reference

&quot; **From&quot; Addresses used by Azure AD**

| From Address | What does it send |
| --- | --- |
| [**o365mc@email2.microsoft.com**](mailto:o365mc@email2.microsoft.com) | Office 365 Message Center |
| [**azure-noreply@microsoft.com**](mailto:azure-noreply@microsoft.com) | Azure AD Access ReviewsAzure AD Connect HealthAzure AD Identity ProtectionAzure AD Privileged Identity ManagementEnterprise App Expiring Certificate NotificationsEnterprise App Provisioning Service Notifications |

**Notifications sent by Azure AD**

| **Notification source** | **What is sent?** | **Where to check?** |
| --- | --- | --- |
| **Technical contact** | Sync Errors | Azure Portal – Properties Blade
 |
| **Office 365 Message Center** | Incident and degradation notices of Identity Services and O365 backend services | Office Portal |
| **Identity Protection Weekly Digest** | Identity Protection Digest
 | Azure AD Identity Protection Blade |
| **Azure AD Connect Health** | Alert notifications | Azure Portal - Azure AD Connect Health Blade |
| **Enterprise Applications Notifications** | Notifications when certificates are about to expire and provisioning errrors | Azure Portal – Enterprise Application Blade(Each application has its own email address setting) |

#### Learn More

- [Change your organization&#39;s address, technical contact, and more - Office 365](https://support.office.com/en-us/article/change-your-organization-s-address-technical-contact-and-more-a36e5a52-4df2-479e-bb97-9e67b8483e10)
- [Message center in Office 365 - Office 365](https://support.office.com/en-us/article/message-center-in-office-365-38fb3333-bfcc-4340-a37b-deda509c2093)
- [Azure Active Directory Identity Protection notifications | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-identityprotection-notifications)
- [Azure Active Directory Connect Health operations | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/connect-health/active-directory-aadconnect-health-operations#enable-email-notifications)
- [Azure Active Directory Reporting Notifications | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/active-directory-reporting-notifications)

## Operational Surface Area

### Check: AD FS Lockdown

#### Why is this important?

IF AD FS is only used for Azure AD federation, there are some endpoints that can be turned off to reduce surface area.

Similarly, it is recommended to enable Extranet Soft Lockout to contain the risk of brute attackings block on-premises Active Directory.

ADFS 2016 and higher provide extranet smart lockout which will help to mitigate password spray attacks.

#### Recommendations

| **Where to find the data for this check?**
- Output file of Task 3: ADFSEnabledEndpoints.csv
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| … **WS-Trust Endpoints other than usernamemixed and windowstransport are enabled -AND-**  **AD FS is only used for Azure AD** | ..Disable unneeded WS-Trust endpoints | P2 |
| … **Extranet soft lockout is not enabled in AD FS** | ..Enable Extranet Soft Lockout | P1 |
| … **Customer has ADFS 2016 or higher and Extranet Smart Lockout is not enabled** | …Enable Extranet Smart Lockout | P2 |

#### Learn More

- [Azure AD and AD FS best practices: Defending against password spray attacks – Enterprise Mobility + Security](https://cloudblogs.microsoft.com/enterprisemobility/2018/03/05/azure-ad-and-adfs-best-practices-defending-against-password-spray-attacks/)
- [Configure AD FS Extranet Lockout Protection | Microsoft Docs](https://docs.microsoft.com/en-us/windows-server/identity/ad-fs/operations/configure-ad-fs-extranet-smart-lockout-protection)

### Check: Access to Machines with On-premises Identity Components

#### Why is this important?

Access to the machines where on-prem hybrid components needs to be locked down the same way as your on-premises domain. For example, a backup operator or Hyper-V administrator should not be able to log in to the Azure AD Connect Server to change rules.

In a tiered privilege access model, core services that control enterprise identities in the environment are considered Tier 0. Learn more: [Securing Privileged Access Reference Material | Microsoft Docs](https://docs.microsoft.com/en-us/windows-server/identity/securing-privileged-access/securing-privileged-access-reference-material)

#### Recommendations

| **Where to find the data for this check?**
- Interview Questions
 |
| --- |

| **If you find …** | **We recommend …** | **With this suggested priority …** |
| --- | --- | --- |
| …**Access to On-prem identity components (Sync Machine, AD FS and/or SQL Servers) are not locked down the same way as Domain Controllers****-AND- ****this is not known or no compensating controls** | …Implement lock down consistently | P1 |
| …**Access to On-prem identity components (Sync Machine, AD FS and/or SQL Servers) are not locked down the same way as Domain Controllers****-AND- ****this is not known or no compensating controls** | …Implement lock down consistently | P2 |

####

#### Learn More

- [Securing Privileged Access Reference Material | Microsoft Docs](https://docs.microsoft.com/en-us/windows-server/identity/securing-privileged-access/securing-privileged-access-reference-material)

![](RackMultipart20210714-4-9eusx2_html_2a32c2bc2658c81d.gif)46

# Disclaimer

The information contained in this document represents the current view of Microsoft Corporation regarding the issues discussed as of the date of publication. Because Microsoft is always responding to changing market conditions, this document should not be interpreted as a commitment on the part of Microsoft. Microsoft cannot guarantee the accuracy of any information presented after the date of publication.

MICROSOFT MAKES NO WARRANTIES, EXPRESS, IMPLIED OR STATUTORY, AS TO THE INFORMATION IN THIS DOCUMENT.