
#ipmo -Force AwsCfn


<#
    Adapted from:
        https://s3.amazonaws.com/cloudformation-templates-us-east-1/RDS_MySQL_With_Read_Replica.template
    Listed on:
        http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/sample-templates-services-us-east-1.html

#>


$templateDescription = "AWS CloudFormation Sample Template RDS_MySQL_With_Read_Replica: Sample" +
    " template showing how to create a highly-available, RDS DBInstance with a read replica." +
    " **WARNING** This template creates an Amazon Relational Database Service database instance" +
    " and Amazon CloudWatch alarms. You will be billed for the AWS resources used if you create" +
    " a stack from this template."

$dbInstanceClasses = "db.t1.micro", "db.m1.small", "db.m1.medium", "db.m1.large", "db.m1.xlarge", "db.m2.xlarge", "db.m2.2xlarge", "db.m2.4xlarge", "db.m3.medium", "db.m3.large", "db.m3.xlarge", "db.m3.2xlarge", "db.m4.large", "db.m4.xlarge", "db.m4.2xlarge", "db.m4.4xlarge", "db.m4.10xlarge", "db.r3.large", "db.r3.xlarge", "db.r3.2xlarge", "db.r3.4xlarge", "db.r3.8xlarge", "db.m2.xlarge", "db.m2.2xlarge", "db.m2.4xlarge", "db.cr1.8xlarge", "db.t2.micro", "db.t2.small", "db.t2.medium", "db.t2.large"

Template -Description $templateDescription -JSON -Compress {
    ## If left unspecified, the default Template Format Version is "2010-09-09"


    #region -- Parameters --

    Parameter DBName String -Default "MyDatabase" `
        -MinLength 1 -MaxLength 64 -AllowedPattern "[a-zA-Z][a-zA-Z0-9]*" `
        -Description "The database name" `
        -ConstraintDescription "must begin with a letter and contain only alphanumeric characters."

    Parameter DBUser String -NoEcho `
        -MinLength 1 -MaxLength 16 -AllowedPattern "[a-zA-Z][a-zA-Z0-9]*" `
        -Description "The database admin account username" `
        -ConstraintDescription "must begin with a letter and contain only alphanumeric characters."

    Parameter DBPassword String -NoEcho `
        -MinLength 1 -MaxLength 41 -AllowedPattern "[a-zA-Z0-9]+" `
        -Description "The database admin account password" `
        -ConstraintDescription "must contain only alphanumeric characters."

    Parameter DBAllocatedStorage Number -Default 5 `
        -MinValue 5 -MaxValue 1024 `
        -Description "The size of the database (Gb)" `
        -ConstraintDescription "must be between 5 and 1024Gb."

    Parameter DBInstanceClass String -Default "db.t2.small" `
        -AllowedValues $dbInstanceClasses `
        -Description "The database instance type" `
        -ConstraintDescription "must select a valid database instance type."

    Parameter EC2SecurityGroup String -Default "default" `
        -AllowedPattern "[a-zA-Z0-9\-]+" `
        -Description "The EC2 security group that contains instances that need access to the database" `
        -ConstraintDescription "must be a valid security group name."

    Parameter MultiAZ String -Default false `
        -AllowedValues true,false `
        -Description "Multi-AZ master database" `
        -ConstraintDescription "must be true or false."

    #endregion -- Parameters --

    #region -- Conditions --

    Condition "Is-EC2-VPC" (Fn-Or @(
        (Fn-Equals (Pseudo Region) "eu-central-1")
        (Fn-Equals (Pseudo Region) "cn-north-1")
    ))

    Condition "Is-EC2-Classic" (Fn-Not (Fn-Condition "Is-EC2-VPC"))

    #endregion -- Conditions --

    #region -- Resources --

    Res-EC2-SecurityGroup DBEC2SecurityGroup -Condition "Is-EC2-VPC" `
        -GroupDescription "Open database for access" `
        -SecurityGroupIngress @{
            ## Notice this property takes an array of objects, but
            ## we only specify a single object definition and POSH
            ## will automagically wrap it in a single-element array
            IpProtocol = "tcp"
            FromPort   = "3306"
            ToPort     = "3306"
            SourceSecurityGroupName = (Fn-Ref EC2SecurityGroup)
        }

    Res-RDS-DBSecurityGroup DBSecurityGroup -Condition Is-EC2-Classic `
        -DBSecurityGroupIngress @{
            EC2SecurityGroupName = (Fn-Ref EC2SecurityGroup)
        } `
        -GroupDescription "database access"

    Res-RDS-DBInstance MasterDB -DeletionPolicy Snapshot `
        -Engine MySQL -Tags @{ Name = "Master Database" } {
            Property DBName (Fn-Ref DBName)
            Property AllocatedStorage (Fn-Ref DBAllocatedStorage)
            Property DBInstanceClass (Fn-Ref DBInstanceClass)
            Property MasterUsername (Fn-Ref DBUser)
            Property MasterUserPassword (Fn-Ref DBPassword)
            Property MultiAZ (Fn-Ref MultiAZ)

            Property VPCSecurityGroups (Fn-If Is-EC2-VPC `
                (Fn-GetAtt DBEC2SecurityGroup GroupId) `
                (Pseudo NoValue))

            Property DBSecurityGroups (Fn-If Is-EC2-Classic `
                (Fn-Ref DBSecurityGroup) `
                (Pseudo NoValue))
        }

    Res-RDS-DBInstance ReplicaDB -Tags @{ Name = "Read Replica Database" } {
            Property SourceDBInstanceIdentifier (Fn-Ref MasterDB)
            Property DBInstanceClass (Fn-Ref DBInstanceClass)
        }

    #endregion -- Resources --

    #region -- Outputs --

    Output EC2Platform `
        -Description "Platform in which this stack is deployed" `
        -Value (Fn-If Is-EC2-VPC "EC2-VPC" "EC2-Classic")

    Output MasterJDBCConnectionString `
        -Description "JDBC connection string for the master database" `
        -Value (Fn-Join "" @(
            "jdbc:mysql://"
            (Fn-GetAtt MasterDB "Endpoint.Address")
            ":"
            (Fn-GetAtt MasterDB "Endpoint.Port")
            "/"
            (Fn-Ref DBName)
        ))

    Output ReplicaJDBCConnectionString `
        -Description "JDBC connection string for the replica database" `
        -Value (Fn-Join "" @(
            "jdbc:mysql://"
            (Fn-GetAtt ReplicaDB "Endpoint.Address")
            ":"
            (Fn-GetAtt ReplicaDB "Endpoint.Port")
            "/"
            (Fn-Ref DBName)
    ))

    #endregion -- Outputs --
}

