# Find suitable instance types for an AWS machine image
To create an AWS box configuration you need to specify `supported_instance_types` parameter -  a list of machine types that can be launched with this AMI and are available in a certain [zone](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html). There are 2 ways to get them.

## Use [script](../../scripts/aws/find_supported_instance_types.rb)
This script outputs all instance types that satisfy given parameters. To run this you need to have AWS-CLI tool configured.

### Usage:
```shell script
./scripts/aws/find_supported_instance_types.rb \
    --zone eu-west-1a \
    --ami ami-028f9616b17ba1d53
```

- `--zone` - Amazon [Availability Zone](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)
- `--ami` - Amazon Machine Image id

### Output format:
The script outputs the list of availavle machine types in JSON format
Example:
```json
["c1.medium","c1.xlarge","c3.8xlarge","c3.large","c3.xlarge"]
```

## Find manually
### 1. Find out the parameters of the AMI
```
aws ec2 describe-images  --image-ids ami-028f9616b17ba1d53
```

### 2. List the machine types that meet the requirements of the AMI
```
aws ec2 get-instance-types-from-instance-requirements \
    --architecture-types x86_64 \
    --virtualization-types hvm \
    --instance-requirements "VCpuCount={Min=1},MemoryMiB={Min=1024}" \
    --region eu-west-1 \
    --query InstanceTypes \
    --output text
```
Where:
- `--architecture-types` - the processor architecture type suitable for the AMI
- `--virtualization-types` - [AMI virtualization types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/virtualization_types.html)
- `--instance-requirements` - other parameters of the machine (min CPU count and memory are **required**)
- `--query` - output values
- `--output` - output format

### 3. List the machine types that are present in a certain availability zone
```
aws ec2 describe-instance-type-offerings \
    --location-type "availability-zone" \
    --filters Name=location,Values=eu-west-1a \
    --query "InstanceTypeOfferings[*].[InstanceType]" \
    --output text

```
- `--location-type` - type of filtering: by region or availability zone

### 4. Intersect the lists form steps #2 & #3
