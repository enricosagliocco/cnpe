# CNPE coverage check

Online verification performed against CNCF/Linux Foundation public material.

The CNPE exam is performance-based and validates advanced platform engineering in a Linux remote desktop. CNCF describes it as covering enterprise-grade platform architecture, GitOps/CD, self-service platform APIs, observability/incident remediation, security and governance.

Public domain weighting found online:

| CNPE domain | Weight | Covered by this simulator |
|---|---:|---|
| Platform Architecture and Infrastructure | 15% | Q1, Q4, Q8, Q10, Q17, Q18 |
| GitOps and Continuous Delivery | 25% | Q3, Q5, Q6, Q7, Q20 |
| Platform APIs and Self-Service Capabilities | 25% | Q1, Q8, Q9, Q10 |
| Observability and Operations | 20% | Q2, Q11, Q12, Q17, Q18, Q20 |
| Security and Policy Enforcement | 15% | Q13, Q14, Q15, Q16, Q20 |

Design notes:
- The simulator intentionally mixes tools because public CNPE descriptions emphasize real-world platform engineering rather than one vendor/tool stack.
- The lab reuses the Minikube/Gitea pattern from the previous package but uses different resources, namespaces and task wording.
- It remains exam-like: tasks require terminal work, Git, Kubernetes resources, policy remediation, progressive delivery and operational evidence files.
