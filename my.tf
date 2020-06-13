provider "aws" {
  region     = "ap-south-1"
  profile    = "shivanshk"
}

resource "aws_security_group" "tcp" {
	name      = "allow_tcp"

	ingress { 
		from_port    = 80
		to_port      = 80 
		protocol     = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	ingress { 
		from_port    = 22
		to_port      = 22
		protocol     = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}	

	 egress {
    		from_port       = 0
    		to_port         = 0
    		protocol        = "-1"
    		cidr_blocks     = ["0.0.0.0/0"]
  	}
	
	tags = {
		Name = "allow_tcp"
	}
}


resource  "aws_instance"  "myins" {
	ami             = "ami-0447a12f28fddb066"
	instance_type   = "t2.micro"
	key_name        =  "cloudkey"
	security_groups = ["allow_tcp"]
	
	connection {
    		type        = "ssh"
    		user        = "ec2-user"
   		private_key     = file("C:/Users/Shivansh Khandelwal/Downloads/cloudkey.pem")
    		host        = aws_instance.myins.public_ip
  	}


	provisioner "remote-exec" {
    		inline = [
      			"sudo yum install httpd php git -y",
      			"sudo systemctl restart httpd",
      			"sudo systemctl enable httpd",
			
    		]
 	}		
		
	tags = {
		Name = "myos2"	
	}
}


resource "aws_ebs_volume" "ebs" {
  availability_zone = aws_instance.myins.availability_zone
  size              = 1

  tags = {
    Name = "myebs"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs.id
  instance_id = aws_instance.myins.id
  force_detach = true
}

output "myosip" {
	value = aws_instance.myins.public_ip
}


resource "null_resource" "nulllocal1"{
	provisioner "local-exec" {
		command = "echo ${aws_instance.myins.public_ip} > publicip.txt"
	}
}

resource "null_resource" "nulllocal3"{
	
	depends_on = [
		aws_volume_attachment.ebs_att,
	]

	connection {
    		type        = "ssh"
    		user        = "ec2-user"
   		private_key = file("C:/Users/Shivansh Khandelwal/Downloads/cloudkey.pem")
    		host        = aws_instance.myins.public_ip
  	}

	provisioner "remote-exec" {
    		inline = [
      			"sudo mkfs.ext4 /dev/xvdh",
			"sudo mount /dev/xvdh /var/www/html",
			"sudo rm -rf /var/www/html/*",
			"sudo git clone https://github.com/Shivansh-sk/cloud_task1.git /var/www/html"
    		]
 	}
}


/*
resource "null_resource" "nulllocal2"{

	
	depends_on = [
		null_resource.nulllocal3,
	]
	

	provisioner "local-exec" {
		command = "chrome ${aws_instance.myins.public_ip}"
	}
}
*/




resource "aws_s3_bucket" "s3_bucket" {
	bucket = "buckettask1"
	acl    = "public-read"

	tags   = {
		Name = "task1"
	}
	versioning{
		enabled = true
	}
}

locals {
		s3_origin_id = "mys3Origin"
}

resource "aws_s3_bucket_object" "upload" {

	depends_on =[aws_s3_bucket.s3_bucket]

	bucket 		 = "buckettask1"
	key    		 = "dog.916.jpg"
	source 		 = "C:/Users/Shivansh Khandelwal/Desktop/dog.916.jpg"
	acl	 		 = "public-read"
	content_type = "image or jpeg"
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "buckettask1.s3.amazonaws.com"
    prefix          = "myprefix"
  }


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}