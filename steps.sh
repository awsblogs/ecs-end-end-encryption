https://locusinnovations.com/2018/05/23/aws-end-to-end-ssl-encryption-with-an-application-load-balancer/

###Create the CFT stack with basic networking infrastructure.
Custom VPC
set of Private and public subnets in multiple AZs
A NAT gateway and Internetgateway

Run the atck and export 

STACK NAME :  ECS-END-END-ENCRYPTION

###networking constructs
vpc-089288fec188f87f2
subnet-0227ad9917a717326 - us-east-2a 
subnet-054192b22b9be9c01 - us-east-2b 

sg-0c2d23cd5549682fc, ECS-ENVOY-END-END-ENCRYPT-PublicLoadBalancerSG-1NCNQN5PJBDF

us-west-1

ECSRole arn:aws:iam::551961765653:role/ECS-END-END-ENCRYPTION-ECSRole-1G5R5DBZKFB0
ECSTaskExecutionRole    arn:aws:iam::551961765653:role/ECS-END-END-ENCRYPTION-ECSTaskExecutionRole-URQRCO2HC4E3
PrivateSubnetOne    subnet-0cb23e7b2da6116ec
PrivateSubnetTwo    subnet-01446062d07790b98
PublicSubnetOne subnet-092e36d83b9d0fd51
PublicSubnetTwo subnet-0a41fcbbe7add4b76
SecurityGroup   sg-0ea3f8730146cc784
VPCId   vpc-0a0598d1d7d1dd8b3


export region=us-west-1
export account=551961765653
export AWS_REGION=$region
export DEFAULT_AWS_REGION=us-west-1
##Export key variables
export private_subnet1="subnet-0cb23e7b2da6116ec"
export private_subnet2="subnet-01446062d07790b98"
export public_subnet1="subnet-092e36d83b9d0fd51"
export public_subnet2="subnet-0a41fcbbe7add4b76"
export sg=sg-0ea3f8730146cc784
export vpcId=vpc-0a0598d1d7d1dd8b3
export ecsTaskExecutionRoleArn=arn:aws:iam::551961765653:role/ECS-END-END-ENCRYPTION-ECSTaskExecutionRole-URQRCO2HC4E3



export service_name=ecs-end-end-encryption
export log_group_name=/ecs/ecs-end-end-encryption

#I have created a Hosted zone for my domain in AWS, will use the name for DNS namespace
export dns_namespace=awsblogs.info
##Explain this with snapshops
##Create recordset pointing to ALB

aws ecr create-repository --repository-name ${service_name}-blog-app --region $region
aws ecr create-repository --repository-name ${service_name}-blog-proxy --region $region


export aws_ecr_repository_url_app=551961765653.dkr.ecr.us-east-2.amazonaws.com/aws-end-end-encryption-blog-app
export aws_ecr_repository_url_proxy=551961765653.dkr.ecr.us-east-2.amazonaws.com/aws-end-end-encryption-blog-proxy

# export proxy_image_uri=551961765653.dkr.ecr.us-east-2.amazonaws.com/aws-end-end-encryption-blog-proxy:latest
# export app_image_uri=551961765653.dkr.ecr.us-east-2.amazonaws.com/aws-end-end-encryption-blog-app:latest



export cluster=${service_name}-cluster
##Create ECS cluster
aws ecs create-cluster --cluster-name $cluster --region $region

###cert creation and import cd docker/certs
openssl genrsa 2048 > my-aws-private.key
openssl req -new -x509 -nodes -sha1 -days 3650 -extensions v3_ca -key my-aws-private.key > my-aws-public.crt
openssl pkcs12 -inkey my-aws-private.key -in my-aws-public.crt -export -out my-aws-public.p12

aws acm import-certificate --certificate file://my-aws-public.crt --private-key file://my-aws-private.key --region $region
{
    "CertificateArn": "arn:aws:acm:us-east-2:551961765653:certificate/40a266ab-9d98-4e36-8034-c9a92cded392"
}

export certificateArn=arn:aws:acm:us-west-1:551961765653:certificate/838bca7e-d33b-41e1-b590-97253cd6e506
## create log group
aws logs create-log-group --log-group-name $log_group_name 

###create an ALB

export alb=${service_name}-alb

aws elbv2 create-load-balancer --name $alb --scheme internet-facing --subnets $public_subnet1 $public_subnet2 --security-groups $sg --region $region

export loadbalancerArn=arn:aws:elasticloadbalancing:us-west-1:551961765653:loadbalancer/app/ecs-end-end-encryption-alb/420cd49c9b77c43b

aws elbv2 create-target-group --name https-target --protocol HTTPS --port 443 --health-check-path /service --target-type ip --vpc-id $vpcId --region $region

export targetGroupArn=arn:aws:elasticloadbalancing:us-west-1:551961765653:targetgroup/https-target/4863b81d86c65413


##aws elbv2 register-targets --target-group-arn targetgroup-arn --protocol HTTPS --port 443 --target-type ip

aws elbv2 create-listener --load-balancer-arn $loadbalancerArn \
--protocol HTTPS --port 443  \
--certificates CertificateArn=$certificateArn \
--default-actions Type=forward,TargetGroupArn=$targetGroupArn --region $region


##create images , push to ECR, create td
cd docker 
# export service_name=ecs-end-end-encryption
# export region=us-east-2
# export dns_namespace=awsblogs.info

# export ecsTaskExecutionRoleArn=arn:aws:iam::551961765653:role/ECS-ENVOY-END-END-ENCRYPT-ECSTaskExecutionRole-IBUEBM701EWC

# export proxy_image_uri=551961765653.dkr.ecr.us-east-2.amazonaws.com/aws-end-end-encryption-blog-proxy:latest
# export app_image_uri=551961765653.dkr.ecr.us-east-2.amazonaws.com/aws-end-end-encryption-blog-app:latest

# export aws_ecr_repository_url_app=551961765653.dkr.ecr.us-east-2.amazonaws.com/aws-end-end-encryption-blog-app
# export aws_ecr_repository_url_proxy=551961765653.dkr.ecr.us-east-2.amazonaws.com/aws-end-end-encryption-blog-proxy

envsubst <ecs_task_def.template>ecs_task_def.json

docker build -t ${aws_ecr_repository_url_proxy} -f Dockerfile-proxy .
docker build -t ${aws_ecr_repository_url_app} -f Dockerfile-app .

aws ecr get-login --region $region
docker login -u AWS -p eyJwYXlsb2FkIjoiYzYvQm9SaDEwd0JSTXFiejRwZ1JFUHVZZm9ZZzAveE5rWEJBT25jYk9TZG5oT0pZVW9DL1R6L2RaWlVaYkhQSG9rNFZ4OGw5R0ZLTnRlNGtvTCtnd1lncnVWTWxteE92V3RLbWYvUkNxRkxJb0V5ZXhWUDJISlpWbGVrQk9VV09IeXM2bVZoSzZicHZqZUc5Ykd4bWRzaUVCLzJtT1NwRGpCQldYTnRuV3dQMVJGMFNuelozemdVVmNZQURsS2RmRmRKUDg3V3draHd0dG5GcWpsZzA5bWoxNSt6c29qQTNaSmJsOTF2WHBMM09ROUpTNXZnVUV1RjkrR25vb1cxUzcrei9CQjZ0eTQvYXRwNUxlUGhKUVdrY2lVMVhmYVRkL2x3ZWY1akRqWnBnOVVkN0Y0WDBnbXJ0YzVERWpsNUVaWW5FTHhjNEpPVFhWdGJCdHR1dHM2WFA3VDRzUDdkNTJPMFJSNUtndWtBM0Rua0RqRDl3YmFKS1JVb2dlaC94cmlVbGZKV292bEpMQU1DRVZMUysrY3N2K1lTQWFpNlFFZWRURWRqRS9vN1RtVkszMW82cUlaT3o4T1VEMFo3MjdOUTVNK3hqVk9zL0g0VXVlQlFZaEpNYnYzRm1PYnByWVA2Rk43WTlnQVVNM2p6bWdmMWdnYi9HeEVqcVc3T0dZRFhMS0VuTXhUTnoxZGJIeHhzQzgwNy9zdmUvdldnYTJEa2hJRkNUVGE0bnlOK1BtRzlHTTZXKzBKRlNBb0dUL0lYR0VzTmozV0ZtZ3ZrbXJuUEZES1o4anJiclFrU081R3F5QW1nTFNJUWxLeE9XWnRYdFdwcnFYcDhPTFVIb0cvM3dyN254cGhySWtpWVUrd1hnZGxYanZnWHZhb0FuNmx1M3VodGtxdEtoRExEY2tyNDZOaDE2NktRcTdKdU9xZ3pMZEFWaGl6aHVkQ1ZUUzFkQmxlUnRlKzR6bE81djBUYnAxbGJvM0RxbmZXVENXOFFsNGI2SGZzTmNaQlRCSisxVHZzMHpETTBpNWNqS09IWjZKbGpkZFQ0UU9QdE8zZjNzMFJDVisrTzFpUXVZQmlEVnRQYzY1cGRObk9tVEZWQm55NVZVeGFVN0p0TkNvNEdYN3VPRGdMUGMwOTdjOU5VelJxSjZnaS9CUEsxbFFTZ2dXWVdnR3VXbzVSWUFBaEhweloraXpjWWJwL0pYMm1DbEF3aTdHSys3WU0xLy9KZWMwTDUzT3RDeEJRRW5CWFptY0UxVThsd2MwOHhmSVZPNEJoTzZoY1M0ZUJMb3ZtZjgveHFPbStzUjYyV1E0bHVMRVRUWlMzRDJoK3JQcklZUXlNWkRWOUNsRUxUS0ZzVVZ6NVBmclNUQXpsWWo0RGxLSzhod2JuQldOTW9PakkwT1JQc09uNWpqMmltVHZ3Zz0iLCJkYXRha2V5IjoiQVFFQkFIakI3L2lnd01nNE5Qd2F1cnhTSVl4NEhmbnh1R2MvNDhiRHd2d0RwTllXWmdBQUFINHdmQVlKS29aSWh2Y05BUWNHb0c4d2JRSUJBREJvQmdrcWhraUc5dzBCQndFd0hnWUpZSVpJQVdVREJBRXVNQkVFREVSZUhVb201SUNwNTBQdzJRSUJFSUE3Mmd1SC9NYXFXZFgwb2dSbzMyOFAyMHI2cDFaaStTZkhERndDa3FyZTB3NFgxYUJtT2NETkFuQ1JBN3NsK0lWR0g0RTVCMEN6ZnJqZEJYcz0iLCJ2ZXJzaW9uIjoiMiIsInR5cGUiOiJEQVRBX0tFWSIsImV4cGlyYXRpb24iOjE1ODg1MDUzMzd9  https://551961765653.dkr.ecr.us-east-2.amazonaws.com/aws-end-end-encryption-blog-proxy

docker push ${aws_ecr_repository_url_proxy}
docker push ${aws_ecr_repository_url_app}


cd ../docker
aws ecs register-task-definition --cli-input-json file://ecs_task_def.json --region=$region

Load balancer cname
ecs-end-end-encryption-alb-860337044.us-west-1.elb.amazonaws.com


envsubst <ecs_service_def.template>ecs_service_def.json

##create service 
aws ecs create-service --cluster $cluster --service-name ${service_name}-service --cli-input-json file://ecs_service_def.json --region $region















{
    "serviceName": "ecs-end-end-encryption-service",
    "clusterArn": "arn:aws:ecs:us-east-2:551961765653:cluster/ECS-ENVOY-END-END-ENCRYPT-ECSCluster-Ij26vDDW14h7",
    "taskDefinition": "arn:aws:ecs:us-east-2:551961765653:task-definition/ecs-end-end-encryption:14",
    "loadBalancers": [
                {
                    "targetGroupArn": "arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67",
                    "containerName": "envoy",
                    "containerPort": 443
                }
            ],
    "launchType": "FARGATE",
    "platformVersion": "LATEST",
    "networkConfiguration": {
                "awsvpcConfiguration": {
                    "subnets": [
                        "subnet-054192b22b9be9c01",
                        "subnet-0227ad9917a717326"
                    ],
                    "securityGroups": [
                        "sg-0c2d23cd5549682fc"
                    ],
                    "assignPublicIp": "ENABLED"
                }
            },
    "healthCheckGracePeriodSeconds": 0,
    "schedulingStrategy": "REPLICA",
    "enableECSManagedTags": false,
    "propagateTags": "NONE"
    "desiredCount": 2,
    "role": "arn:aws:iam::551961765653:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"
}


{
    "services": [
        {
            "serviceArn": "arn:aws:ecs:us-east-2:551961765653:service/ecs-end-end-encryption-service",
            "serviceName": "ecs-end-end-encryption-service",
            "clusterArn": "arn:aws:ecs:us-east-2:551961765653:cluster/ECS-ENVOY-END-END-ENCRYPT-ECSCluster-Ij26vDDW14h7",
            "loadBalancers": [
                {
                    "targetGroupArn": "arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67",
                    "containerName": "envoy",
                    "containerPort": 443
                }
            ],
            "serviceRegistries": [
                {
                    "registryArn": "arn:aws:servicediscovery:us-east-2:551961765653:service/srv-okpc6ri5n74wonqu"
                }
            ],
            "status": "ACTIVE",
            "desiredCount": 2,
            "runningCount": 2,
            "pendingCount": 0,
            "launchType": "FARGATE",
            "platformVersion": "LATEST",
            "taskDefinition": "arn:aws:ecs:us-east-2:551961765653:task-definition/ecs-end-end-encryption:14",
            "deploymentConfiguration": {
                "maximumPercent": 200,
                "minimumHealthyPercent": 100
            },
            "deployments": [
                {
                    "id": "ecs-svc/8230772251058458319",
                    "status": "PRIMARY",
                    "taskDefinition": "arn:aws:ecs:us-east-2:551961765653:task-definition/ecs-end-end-encryption:14",
                    "desiredCount": 2,
                    "pendingCount": 0,
                    "runningCount": 2,
                    "createdAt": 1588468621.487,
                    "updatedAt": 1588469227.482,
                    "launchType": "FARGATE",
                    "platformVersion": "1.3.0",
                    "networkConfiguration": {
                        "awsvpcConfiguration": {
                            "subnets": [
                                "subnet-054192b22b9be9c01",
                                "subnet-0227ad9917a717326"
                            ],
                            "securityGroups": [
                                "sg-0c2d23cd5549682fc"
                            ],
                            "assignPublicIp": "ENABLED"
                        }
                    }
                }
            ],
            "roleArn": "arn:aws:iam::551961765653:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS",
            "events": [
                {
                    "id": "70f2ec4b-7678-4cc9-88cc-9b2401b33eff",
                    "createdAt": 1588512454.821,
                    "message": "(service ecs-end-end-encryption-service) has reached a steady state."
                },
                {
                    "id": "d764d0c7-5b14-46f4-b8a8-4f3fc341cbb5",
                    "createdAt": 1588490845.933,
                    "message": "(service ecs-end-end-encryption-service) has reached a steady state."
                },
                {
                    "id": "127b9b7f-ccaf-4c17-9e5f-94fa092980ae",
                    "createdAt": 1588469227.508,
                    "message": "(service ecs-end-end-encryption-service) has reached a steady state."
                },
                {
                    "id": "8030df32-3cfc-4d7c-84bf-ff3e2abd8c89",
                    "createdAt": 1588469181.041,
                    "message": "(service ecs-end-end-encryption-service) registered 1 targets in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67)"
                },
                {
                    "id": "27150263-7385-45b7-a954-1d691a3aba2e",
                    "createdAt": 1588469114.973,
                    "message": "(service ecs-end-end-encryption-service) has started 1 tasks: (task b5fbc2e2-6f2c-4ec9-9e25-028538cc0c1c)."
                },
                {
                    "id": "7876d05c-9076-4b80-b8ac-a6a98b7553c9",
                    "createdAt": 1588469105.788,
                    "message": "(service ecs-end-end-encryption-service) has stopped 1 running tasks: (task d6ce452b-afcb-415a-8d87-e75911e2441d)."
                },
                {
                    "id": "a9ccacf7-d524-44b3-ac74-e563f017b5b6",
                    "createdAt": 1588469105.762,
                    "message": "(service ecs-end-end-encryption-service) deregistered 1 targets in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67)"
                },
                {
                    "id": "6cbf4e05-a148-424d-a303-33a6ef3f83f1",
                    "createdAt": 1588469105.732,
                    "message": "(service ecs-end-end-encryption-service) (port 443) is unhealthy in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67) due to (reason Health checks failed with these codes: [404])."
                },
                {
                    "id": "e71a7486-3d74-4abf-b56e-f26840ff1938",
                    "createdAt": 1588469093.347,
                    "message": "(service ecs-end-end-encryption-service) has started 1 tasks: (task 603363cd-41e0-4433-ba08-7741da2980a8)."
                },
                {
                    "id": "45cb1221-84e3-48ca-a7fe-40e4741a411f",
                    "createdAt": 1588469083.326,
                    "message": "(service ecs-end-end-encryption-service) has stopped 1 running tasks: (task 6aeb5f51-f1a0-4a48-b8ce-583e040aa085)."
                },
                {
                    "id": "848b6f1e-2e0e-4e98-8e73-5eaf27b0b669",
                    "createdAt": 1588469083.3,
                    "message": "(service ecs-end-end-encryption-service) deregistered 1 targets in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67)"
                },
                {
                    "id": "d8dea123-98f4-44b0-955c-c59f497b1a53",
                    "createdAt": 1588469083.275,
                    "message": "(service ecs-end-end-encryption-service) (port 443) is unhealthy in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67) due to (reason Health checks failed with these codes: [404])."
                },
                {
                    "id": "76521f26-cfe9-43f8-9912-654fbf7963b2",
                    "createdAt": 1588468939.971,
                    "message": "(service ecs-end-end-encryption-service) registered 1 targets in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67)"
                },
                {
                    "id": "35c63e36-2388-4abd-9d23-2f12c07cce1f",
                    "createdAt": 1588468873.941,
                    "message": "(service ecs-end-end-encryption-service) has started 1 tasks: (task d6ce452b-afcb-415a-8d87-e75911e2441d)."
                },
                {
                    "id": "7c40f2f4-5a08-4054-9f41-33de1b16776f",
                    "createdAt": 1588468861.518,
                    "message": "(service ecs-end-end-encryption-service) has stopped 1 running tasks: (task 1a027791-0390-4530-b878-980d82896517)."
                },
                {
                    "id": "34f1d8f2-bc9c-475d-a7ce-b5f33bd93fd2",
                    "createdAt": 1588468861.494,
                    "message": "(service ecs-end-end-encryption-service) deregistered 1 targets in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67)"
                },
                {
                    "id": "a3f03fff-8252-4592-86e2-4c4bde2086ad",
                    "createdAt": 1588468861.465,
                    "message": "(service ecs-end-end-encryption-service) (port 443) is unhealthy in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67) due to (reason Health checks failed with these codes: [502])."
                },
                {
                    "id": "39e69468-a524-4233-b321-595324efe09a",
                    "createdAt": 1588468861.449,
                    "message": "(service ecs-end-end-encryption-service) has started 1 tasks: (task 6aeb5f51-f1a0-4a48-b8ce-583e040aa085)."
                },
                {
                    "id": "575f1073-c9fe-47e0-8324-deb9a015bced",
                    "createdAt": 1588468848.574,
                    "message": "(service ecs-end-end-encryption-service) has stopped 1 running tasks: (task f86c78b9-4db1-4312-983c-0f2cb417db7e)."
                },
                {
                    "id": "ddac2be8-1861-4563-b445-fb2ee251a81d",
                    "createdAt": 1588468848.55,
                    "message": "(service ecs-end-end-encryption-service) deregistered 1 targets in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67)"
                },
                {
                    "id": "68825d9a-4970-4138-b651-d79880b32e3b",
                    "createdAt": 1588468848.52,
                    "message": "(service ecs-end-end-encryption-service) (port 443) is unhealthy in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67) due to (reason Health checks failed with these codes: [502])."
                },
                {
                    "id": "ffda6837-e797-4a8b-8c20-d5f2e788a3f1",
                    "createdAt": 1588468703.832,
                    "message": "(service ecs-end-end-encryption-service) registered 1 targets in (target-group arn:aws:elasticloadbalancing:us-east-2:551961765653:targetgroup/https-tg/fa8c43c4060dcc67)"
                },
                {
                    "id": "e01fda7b-1b25-4e92-aafb-1b39c4be48b2",
                    "createdAt": 1588468628.875,
                    "message": "(service ecs-end-end-encryption-service) has started 2 tasks: (task 1a027791-0390-4530-b878-980d82896517) (task f86c78b9-4db1-4312-983c-0f2cb417db7e)."
                }
            ],
            "createdAt": 1588468621.487,
            "placementConstraints": [],
            "placementStrategy": [],
            "networkConfiguration": {
                "awsvpcConfiguration": {
                    "subnets": [
                        "subnet-054192b22b9be9c01",
                        "subnet-0227ad9917a717326"
                    ],
                    "securityGroups": [
                        "sg-0c2d23cd5549682fc"
                    ],
                    "assignPublicIp": "ENABLED"
                }
            },
            "healthCheckGracePeriodSeconds": 0,
            "schedulingStrategy": "REPLICA",
            "enableECSManagedTags": false,
            "propagateTags": "NONE"
        }
    ],
    "failures": []
}






