# Intro

**TimberFire Technologies** is a Software Platform as a Service provider.
They will like to incorporate Kubernetes as a Service (KaaS) solutions for their customers.
For this purpose, they have brought in Red Hat to help determine the technology stack.
They have worked with Red Hat before and have been exposed to OpenShift.
However, this time they have new requirements and are not sure OpenStack by itself will help them.
After interviewing their customers, TimberFire Technologies have compiled their top requirements:

Their customers will like to be able to use matured cloud services with established SLAs from reputable cloud providers.
The top services required by their customers are SQL and NoSQL databases, Object Stores, and Message Brokers.
Their customer will like to be able to run tests in multiple environments before deploying to production.
These environments will be short lived and sometimes even ephemeral.
It is important that each customer's test environment can be provisioned and configured quickly (less than a minute).
They will like to be efficient with their infrastructure and are therefore looking to set up their platform to be multi-tenant.
They will like to allow their customers to provision their services on-demand or have them available in a service pool ready to be consumed by their application.

They use Primaza for handling customer tenants and to provide easy service discovery and binding.

A new customer `CUSTOMER_NAME` wants to use their service.
After an account is created a tenant named `mytenant` is set up by KaaS' automation for `CUSTOMER_NAME`.
