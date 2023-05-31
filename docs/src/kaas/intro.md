# Case Study

**TimberFire Technologies** is a Software and Platform as a Service provider.
They will like to incorporate Kubernetes as a Service (KaaS) solutions for their customers.
For this purpose, they have brought in Red Hat to help determine the technology stack.
They have worked with Red Hat before and have been exposed to OpenShift.
However, this time they have new requirements and are not sure OpenStack by itself will help them.
After interviewing their customers, TimberFire Technologies have compiled their top requirements.

* Their customers will like to be able to use matured cloud services with established SLAs from reputable cloud providers.
The top services required by their customers are SQL and NoSQL databases, Object Stores, and Message Brokers.

* Their customer will like to be able to run tests in multiple environments before deploying to production.
These environments will be short lived and sometimes even ephemeral.
It is important that each customer's test environment can be provisioned and configured quickly.

* They will like to be efficient with their infrastructure and are therefore looking to set up their platform to be multi-tenant.

* They will like to allow their customers to provision their services on-demand or have them available in a service pool ready to be consumed by their application.

After analysing TimberFire’s requirements, Red Hat has determined that a Pipeline using OpenShift will be a good baseline for TimberFire KaaS offering.
In addition to OpenShift, Red Hat has determined that given their cloud service requirements, a new product, currently under development, called **Primaza** is a good candidate to be evaluated by TimberFire.

TimberFire will like to work on a PoC with Red Hat and one of their customers: **Sapiens Inc.**
<br/>
Sapiens is building an online retail application that specifically requires a NoSQL database, a PostgreSQL Database and a Queue.
Before the PoC work starts Red Hat will like to show TimberFire and Sapiens Engineering Leadership a Demo of their Primaza v0.1 release to gauge whether there are any missing requirements that can be addressed in parallel while the PoC is being run.
