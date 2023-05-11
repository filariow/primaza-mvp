# Service Administrator: 3rd party integration


Then the Service Administrator is asked for configuring the Primaza 3rd-party integration with AWS Service Catalog already configured by the team.

![image](../../imgs/aws-service-catalog.png)

The integration mechanism relies on AWS Service Catalog's event published on an SNS topic and processed by a custom Lambda function.
The Lambda function processes the event and creates/updates/deletes the RegisteredService in Primaza Control Plane.

Finally, the Service Administrator is asked to deploy a Product from the AWS Service Catalog.
