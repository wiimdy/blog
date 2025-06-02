---
title: "First Audit Guide"
date: 2025-05-01T09:23:02+09:00
authors:
  - wiimdy
description: "A beginner's guide to smart contract auditing, covering the process, mindset, and tools."
tags:
  - Web3
  - Audit
  - Security
categories:
  - Web3
image:
  path: "/assets/img/upside_img/audit.png"
---

"The rights to this article belong to Upside Academy."

# First Audit Guide

Hello, I'm wiimdy from the 2nd of Upside Academy, and I'm the author of this article.
While working on various practical assignments at Upside Academy, there was one that particularly stood out. It was an auditing exercise where we audited a protocol created by another Upsider, and another assignment involved analyzing and reproducing actual Web3 hacking incidents. These two experiences went beyond audit theory or tool usage, prompting me to deeply consider what perspective to adopt when reviewing code and how to build secure protocols. I decided to write this article to explain the audit methods and processes I learned through these assignments for those who are new to auditing.

In Web3, auditing is often perceived as a task for experts or security firms. Therefore, those interested in auditing might wonder, "Where do I even begin?" or "Is it possible if I don't know the tools well and can't fully understand the code?" This article aims to guide beginners on the thought process, methods, and perspectives needed when conducting an audit.

## 1. What's Important in an Audit

I believe an audit is more than just finding bugs in code; it's a process of examining and enhancing the overall security and logical consistency of a protocol. Especially when compared to bug bounties, auditing goes a step further than just finding problems. The core of auditing is to deeply analyze questions like, "Is the system operating safely as intended?" and "Are there any logical loopholes or structural vulnerabilities?"

To achieve this, auditors must move beyond simple code reviews. They need to accurately understand the overall system architecture and concept of the protocol, meticulously compare and review whether the actual code implementation aligns with the intended logic, and check for vulnerabilities. Therefore, considerations should include not only mistakes in the code itself but also the possibility of business logic flows being exploited in unexpected ways, and indirect threats that might arise from integration with external protocols. From this perspective, auditing is less about simply finding problems and more about thinking about risks and establishing the stability of the protocol.

## 2. Audit Process

Now, let's look at the actual sequence of an audit. Various methodologies exist for auditing, and approaches can differ depending on the situation. I believe it's important to apply a method that suits your own style.

In this article, I'll use one of my Upside Academy assignments, "Web3 Project - NFT Auction," as the audit target for explanation. I encourage you to try auditing this protocol yourself after reading this article.

[Project GitHub](https://github.com/wiimdy/UpNFT)

### 2.1. Reading the Docs

The starting point of an audit is understanding the protocol. The best way to understand a protocol is by reading the documentation (Docs) provided by the protocol.
Docs contain explanations of the protocol's purpose, how it works, and descriptions of core contracts, which greatly helps in grasping the overall flow.
![image](/assets/img/upside_img/pic1.png)
Part of NFT Auction's Docs (Photo 1)

You can read the NFT Auction's Docs by referring to `Up_NFT_Docs.pdf` in the GitHub repository. This will give you a general understanding of how NFT Auction works.

### 2.2. Using it Yourself

While reading documents is important, actually using the protocol yourself provides a much more intuitive understanding. By experiencing the protocol's flow directly through the UI, you can see how the explanations in the Docs are implemented in practice and visually identify the flow of each function and any abnormal behavior.
Furthermore, using it yourself naturally raises suspicions about potential problem areas and questions about the logic, which helps to strengthen motivation and curiosity for the audit.

![image](/assets/img/upside_img/pic2.png)
NFT listing screen on OpenSea, an NFT Auction site (Photo 2)

Since I didn't apply a UI to the protocol I created, I've used a screenshot from OpenSea, one of the NFT Auction sites, showing the NFT sales registration screen. This allows you to visually understand what arguments the "listingAuction" function requires and the registration process. Additionally, by analyzing the transaction (tx) generated from actual execution, you can understand the internal logic at play.

### 2.3. Analyzing Protocol Structure and Code

Now it's time for code analysis. Since audit target protocols are usually public on GitHub, you understand the overall code flow by analyzing the contract structure and files. Analyze the code while considering which functions are callable by external users and whether the implementation of each function aligns with the documentation and the protocol's intent. User-facing functions often start as public/external functions, so focusing the analysis on these can make the process smoother.

![image](/assets/img/upside_img/pic3.png)
The ListingAuction function in NFT Auction (Photo 3)

For example, when analyzing this function, you would first understand its role (a function to list an NFT for auction) and then analyze its internal functions to see what specific logic is executed. Compare whether the function accurately executes the logic intended by the protocol.

### 2.4. Creating a Data Flow Model

After reading the documents and analyzing the code, I recommend creating a functional flow diagram of the project yourself. Key considerations when creating a data flow model are Entity, Entry Point, Entity trust assumption, and Asset. By considering who the participants are in the function flow, which functions are accessed, where the system's trusted zones are, and what assets the system protects, and then drawing the data flow model yourself, state transitions and asset movements that were confusing from just looking at the code become visually organized. Visualizing this flow is very useful later for threat modeling.

![image](/assets/img/upside_img/pic4.png)
Data Flow Model of the transaction process in NFT Auction (Photo 4)

The above flow diagram illustrates the process of asset transfer as an auction progresses in NFT Auction. This allows you to see the sequence of the transaction process at a glance.

### 2.5. Creating a Threat Model

Now we come to what can be called the most important step in auditing: creating a threat model. In this stage, you imagine how an attacker might exploit the protocol and identify potential vulnerability points in advance. I mainly use the data flow model to simulate how an attacker might enter the protocol and what assets they could affect.

![image](/assets/img/upside_img/pic5.png)
Threat modeling example (Photo 5) [link](https://composable-security.com/blog/threat-modeling-for-smart-contracts-best-step-by-step-guide/)

Structure and consolidate attack scenarios in the format: Who (attacker) / What (assets to protect/things that shouldn't be altered) / How (attack method) / What result (e.g., fund theft/bridge halt).
Then, for each scenario, judge the severity of the vulnerability based on the following two metrics:

Impact: How severe are the consequences for the project?
Likelihood: How likely is this attack to actually occur?

Combine these two metrics to prioritize vulnerabilities.

![image](/assets/img/upside_img/pic6.png)
Vulnerability Severity Table (Photo 6)

### 2.6. Actual Vulnerability Verification

The flows presumed to be risky during the threat modeling phase must now be verified through testing.
Auditing is not just a theoretical exercise; it's a process of proving whether an attack scenario is actually possible.

At this stage, I use Foundry to set up a test environment. Foundry is suitable for verifying audit scenarios as it allows for setting up test environments and writing scenarios.

![image](/assets/img/upside_img/pic7.png)
Test case example (Photo 7)

For example, to test the process of re-listing an already listed NFT, reconstruct the scenario. Since it's an already registered ID, check if a Revert occurs during the validation process. Writing test cases becomes easier if you consider the given situation (Given) and the problematic situation (When). Through testing, you can consider whether the attack scenario is feasible, its likelihood, and what conditions are necessary.

### 2.7. Writing the Audit Report

An audit report is not simply a document that says, "There is a vulnerability." It must be organized in a logical and structured flow so that the reader (protocol team, users) can understand "why this is dangerous, what impact it has, and how it can be fixed."

The audit report format is as follows:

1.  Issue Summary
    A core explanation of the issue. Should be summarizable in one line.
    → Example: "Re-entrancy possible due to state change after external call in the withdraw function."
2.  Vulnerability
    What impact can this issue have on the entire protocol?
    → Example: Asset loss, privilege escalation, malfunction, governance bypass, etc., including actual damage and its scope.
3.  Proof of Concept (PoC)
    Reproducible test code or minimal conditions.
4.  Recommendation
    Proposed solution. Code-level fixes, adding state checks, restricting permissions, etc.

![image](/assets/img/upside_img/pic8.png)
Audit Report writing example (Photo 8)

When writing the report, it's important not to just point out a single line of code, but to explain the meaning of the vulnerability arising from that line and its risk within the logic. You should consider not just what part is problematic due to this vulnerability, but also how it could affect the protocol.

Conclusion
Anyone new to auditing will feel overwhelmed at first. You don't know where to start, the code is complex, and audit reports might seem like they're written in an expert's language. That's why this article aimed to share the actual process and mindset for those trying auditing for the first time, focusing on what perspective to approach it with.

In the future, Web3 will connect more projects and assets, and accordingly, the importance and demand for auditing will continue to increase. Therefore, individuals who can grasp complex structures and asset flows and identify potential problems at the design level will become increasingly important.
If you start training in the audit process step by step from now on, I believe you can grow into someone who can build trust and safety in Web3.

I hope this article serves as a small starting point for your first audit.

Audit Platform Information

If you've read this article and want to try auditing but don't know where to start, the three audit platforms introduced below might be helpful.
These platforms mostly operate in an Audit Contest format, where they disclose the source code and audit scope for a certain period, allowing anyone to participate.

[Code4rena](https://code4rena.com/audits)

[Sherlock](https://audits.sherlock.xyz/contests)

[Immunefi](https://immunefi.com/audit-competition/)

References

[Threat Modeling for Smart Contracts: Best Step-by-Step Guide](https://composable-security.com/blog/threat-modeling-for-smart-contracts-best-step-by-step-guide)

[chainlight - Audit Report](https://2375752643-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FBzRN6jIuKMpPX3uxX5aw%2Fuploads%2FmiLUwoyAQ1YfI2VZZ7yM%2F%5BChainLight%5D%20Kurrency%20PLAY%20Security%20Audit%20v1.0.pdf?alt=media&token=1fe48e3d-51cc-4d86-aaf7-bab2cc023775)
