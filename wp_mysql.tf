# Login to AWS

provider "aws" {
	region 				= "ap-south-1"
	profile 			= "arpit"
}


# Creating the VPC

resource "aws_vpc" "arpit-vpc" {
	cidr_block 			 = "192.168.0.0/16"
	instance_tenancy 	 = "default"
	enable_dns_hostnames = "true"
	
	tags = {
		Name = "arpit-vpc"
	}
}


# Creating Subnet

# Public Subnet
resource "aws_subnet" "pub-subnet" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	vpc_id 				= aws_vpc.arpit-vpc.id
	cidr_block 			= "192.168.0.0/24"
	availability_zone 	= "ap-south-1a"
	map_public_ip_on_launch  = "true"
	
	tags = {
		Name = "pub-subnet"
	}
}


# Private Subnet
resource "aws_subnet" "pri-subnet" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	vpc_id 				= aws_vpc.arpit-vpc.id
	cidr_block 			= "192.168.1.0/24"
	availability_zone 	= "ap-south-1b"
	
	tags = {
		Name = "pri-subnet"
	}
}


# Creating Internet Gateway

resource "aws_internet_gateway" "arpit-ig" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	vpc_id 				= aws_vpc.arpit-vpc.id
	
	tags = {
		Name = "arpit-ig"
	}
}



# Creating Route Table for Internet Gateway for Public Access

resource "aws_route_table" "arpit-rt" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	vpc_id 			    = aws_vpc.arpit-vpc.id
	route {
		cidr_block 		= "0.0.0.0/0"
		gateway_id 		= aws_internet_gateway.arpit-ig.id
    }
  
	tags = {
		Name = "arpit-rt"
	}
}


# Association of Route table to Public Subnet

resource "aws_route_table_association" "pub-subnet-rt" {
	depends_on 			= [ aws_route_table.arpit-rt , aws_subnet.pub-subnet ]
	
	subnet_id 			= aws_subnet.pub-subnet.id
	route_table_id 		= aws_route_table.arpit-rt.id
}





# Creating Elatic IP for static IP

resource "aws_eip" "eip" {
	vpc 				= true
	depends_on 			= [ aws_internet_gateway.arpit-ig , ]

	tags = {
		Name = "arpit-eip"
    }
}



# Creating NAT Gateway

resource "aws_nat_gateway" "nat-gateway" {
	depends_on			= [ aws_subnet.pub-subnet , aws_subnet.pri-subnet ]

	allocation_id 		= aws_eip.eip.id
	subnet_id     		= aws_subnet.pub-subnet.id

	tags = {
		Name = "nat-gateway"
	}
}


# Creating Route Table for our Nat Gateway

resource "aws_route_table" "arpit-nat-rt" {
	depends_on 			= [ aws_vpc.arpit-vpc , aws_nat_gateway.nat-gateway ]
	
	vpc_id 			    = aws_vpc.arpit-vpc.id
	route {
		cidr_block 		= "0.0.0.0/0"
		gateway_id 		= aws_nat_gateway.nat-gateway.id
    }
  
	tags = {
		Name = "arpit-nat-rt"
	}
}


# Associating route table to private subnet

resource "aws_route_table_association" "nat-rt" {
	depends_on			= [ aws_route_table.arpit-nat-rt , ]
	
	subnet_id      		= aws_subnet.pri-subnet.id
	route_table_id 		= aws_route_table.arpit-nat-rt.id
}





# Creating Security Group for WordPress

resource "aws_security_group" "wp-sg" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	name        		= "wp-allow"
	description 		= "https and ssh"
	vpc_id      		= aws_vpc.arpit-vpc.id

	ingress {
		from_port   = 22
		to_port     = 22
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
  
	ingress {
		from_port   = 80
		to_port     = 80
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name ="wp-allow"
	}
}


# Creating Security Group for MySQL

resource "aws_security_group" "msql-sg" {
	depends_on 			= [ aws_vpc.arpit-vpc ,]
	
	name        	= "msql-allow"
	description 	= "mysql-allow-port-3306"
	vpc_id      	= aws_vpc.arpit-vpc.id

	ingress {
		from_port   = 3306
		to_port     = 3306
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
  
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name =	"msql-allow"
	}
}


# Creating security group for Bastion host Login by admin

resource "aws_security_group" "admin-bastion" {
	name        	= "bastion-host"
	description 	= "ssh login into bastion host"
	vpc_id      	= aws_vpc.arpit-vpc.id

	ingress {
		description 	= "ssh"
		from_port   	= 22
		to_port     	= 22
		protocol    	= "tcp"
		cidr_blocks 	= ["0.0.0.0/0"]
	}

	egress {
		from_port   	= 0
		to_port     	= 0
		protocol    	= "-1"
		cidr_blocks 	= ["0.0.0.0/0"]
	}

	tags = {
		Name = "admin-bastion"
	}
}



# Creating security Group for MySQL to allow bastion host

resource "aws_security_group" "bastion-allow" {
	name        	= "bastion-to-mysql"
	description 	= "ssh from bastion"
	vpc_id      	= aws_vpc.arpit-vpc.id

	ingress {
		description 	= "ssh"
		security_groups =[ aws_security_group.admin-bastion.id , ]
		from_port   	= 22
		to_port     	= 22
		protocol    	= "tcp"
		cidr_blocks 	= ["0.0.0.0/0"]
	}

	egress {
		from_port   	= 0
		to_port     	= 0
		protocol    	= "-1"
		cidr_blocks 	= ["0.0.0.0/0"]
	}

	tags = {
		Name = "bastion-allow"
	}
}



# Launch WordPress Instance

resource "aws_instance" "wp-os" {
	depends_on 			= [ aws_subnet.pub-subnet , aws_security_group.wp-sg]
	
	ami                	= "ami-7e257211" 
    instance_type      	= "t2.micro"
    key_name       	   	= "mykey"
    security_groups	 	= [aws_security_group.wp-sg.id ,]
    subnet_id       	= aws_subnet.pub-subnet.id
 
	tags = {
		Name = "wp-os"
	}
}


# Launching MySQL Instance

resource "aws_instance" "mysql-os" {
	depends_on 			= [ aws_subnet.pri-subnet , aws_security_group.msql-sg]
	
	ami           		= "ami-08706cb5f68222d09"
	instance_type 		= "t2.micro"
	key_name 			= "mykey"
	security_groups 	= [aws_security_group.msql-sg.id , aws_security_group.bastion-allow.id ]
	subnet_id 			= aws_subnet.pri-subnet.id
 
	tags = {
		Name = "mysql-os"
	}
}


# Launching Bastion Host

resource "aws_instance" "bastion-host" {
	ami 				= "ami-0732b62d310b80e97"
	instance_type 		= "t2.micro"
	key_name 			= "mykey"
	availability_zone 	= "ap-south-1a"
	subnet_id 			= aws_subnet.pub-subnet.id
	security_groups 	= [ aws_security_group.admin-bastion.id , ]

	tags = {
		Name = "bastion-host"
    }
}




# Get public IP of WordPress

output "wordpress-ip" {
	value 				= aws_instance.wp-os.public_ip
}

# Get Instance ID of WordPress

output "WP-id" {
	value				= aws_instance.wp-os.id
}


# Get EIP
output "eip-id" {
	value				= aws_eip.eip.id
}


# Connect to the WordPress

resource "null_resource" "open-wp"  {

depends_on = [aws_instance.wp-os, aws_instance.mysql-os]

	provisioner "local-exec" {
	    command = "start chrome ${aws_instance.wp-os.public_ip}"
  	}
}
