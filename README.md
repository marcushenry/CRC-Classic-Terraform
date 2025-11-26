# Classic Cloud Resume Challenge

**Summary of the Infrastructure Challenge**

This challenge successfully established a fundamental, secure, and cost-efficient cloud environment using Infrastructure as Code (Terraform). 
The primary goal achieved was hosting your resume PDF, which is stored in S3, under a custom domain name (`resume.marcushenry.ca`). 
This was accomplished by provisioning a minimal EC2 instance in a custom VPC, configuring it to run an Apache web server. 
The server's boot script (`user_data`) automatically installed Apache and replaced the default homepage with an HTML **meta refresh tag** that instantly redirects all visitors to your secure S3 URL. 
This setup minimizes costs while providing a professional, custom-branded public URL. 
The final troubleshooting step involved recognizing that stopping and starting the instance causes its Public IP to change, which breaks the DNS record—a classic behavior that is normally solved by adopting an Elastic IP.


