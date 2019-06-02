# Monitor Intune Solution

Intune is the fast growing device management solution of Microsoft. One main functionality of Intune are compliance policies, which allow the verification of specific settings on a device. There is one missing feature, which I hope will be added soon, but for the time being I developed a workaround and share it with you. In compliance policies you can define actions for non-compliance, at the moment you have only two options:
- Mark the device as uncompliant (immediately or with a delay)
- Send an E-Mail to the enduser and optionally to fix defined users (immediately or with a delay)
The first option is good an helpful together with Azure AD Conditional Access, but the second one is not always optimal. For example, when your users do not have administrative permissions, then the e-mail can be confusing to the end-user. Also you can't use dynamic strings, for example what setting is non-compliant and how it can be remediated. Additionally, a lot of companies would like to see such alerts in their Splunk/SIEM system or create an incidents in the ticketing system. The providers of such solutions have often a possibility to receive e-mails and to parse the information in it, but the mail messages of Intune are so generic, that no helpful events/incidents can be created.

Read more (https://blog.basevision.ch/2019/06/intune-integration-into-siem-splunk-or-an-incident-management-system/)