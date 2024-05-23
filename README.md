# The identity of a Linux system: Research and Proof-of-Concept.

This repository contains the Proof of Concept and Bachelor Thesis focused on the intersection of cybersecurity and system automation, particularly emphasizing the adoption of Infrastructure as Code (IaC) to meet the requirements of the NIS2 directive ("Network and Information Security").

## Abstract

The subjects of cybersecurity and system automation are both crucial in the IT world.
However, merging these two topics isn't always straightforward for every company.
With the new NIS2 directive, also known as "Network and Information Security", companies are mandated to protect their systems against cyber attacks. The scope of sectors falling under this directive has significantly expanded compared to its predecessor. One of the obligations companies must fulfill is mapping out all critical systems that impact their operations.

Infrastructure as Code can offer a solution to this challenge.
By describing a company's current infrastructure in code, it provides an overview of all systems in use.
Yet, many companies, especially SMEs, find it challenging to transition to an Infrastructure as Code environment.
This can be due to various reasons, such as lack of knowledge, time, and budget.

This bachelor thesis focuses on examining potential tools that can aid in the transition to an Infrastructure as Code environment by compiling a configuration inventory.
Existing tools that can contribute to this will be explored.
Additionally, an analysis will be conducted on the different attributes of Linux systems that are best included in a configuration inventory.

Subsequently, a Proof of Concept will be developed, wherein a Bash script will be written to gather basic information from a Linux system and convert it into a set of clear files.
This script will be executed on five different Debian servers, each with its own role within the environment.

This bachelor thesis explores the use of tools such as Nmap and LinPEAS-ng for discovering the configuration of a Linux system.
Nmap is primarily used for exploring network configurations, while LinPEAS-ng provides deeper insight into the configuration of the Linux system itself and identifies potential security risks.
The developed script forms a solid foundation upon which administrators can build by adding additional functionalities and finding solutions for any limitations identified during the script's development.

# Contents

- `/doc/bachproef` contains the LaTeX source code of the Bachelor Thesis.
- `/doc/voorstel` contains the LaTeX source code of the Proposal.
- `/src/poc` contains the code related to the configuration of the virtual environment and the deployment of the Proof of Concept.
- `/src/tools` contains the script developed for the Proof of Concept.
- `/demos/` contains the demo files for the Proof of Concept and other discussed tools.

# Latest Build

For the latest build of the Bachelor Thesis, please refer to the following link: [Bachelor Thesis](https://github.com/AntonVanAssche/hogent-bachelorproef/actions/workflows/thesis-docker-tex-to-pdf.yml).
The proposal can be found [here](https://github.com/AntonVanAssche/hogent-bachelorproef/actions/workflows/proposal-docker-tex-to-pdf.yml)

# Authors

- Author: [Anton Van Assche](https://www.github.com/AntonVanAssche)
- Promoter: [Thomas Clauwaert](https://github.com/Ciberth)
- Co-promoter: [Bert Deferme](https://www.github.com/bdeferme)
