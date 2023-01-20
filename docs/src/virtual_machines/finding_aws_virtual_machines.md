# Finding AWS virtual machines
MDBCI stores various information about every provided box - it's provider, distribution, architecture, etc.
You can find that information into `configuration/boxes/` directory.

Every AWS box requires AMI (Amazon Machine Image) id. There is several ways to find the desired image.

## 1. Looking at official distributions wiki
Many popular linux distributions have a detailed page with official AMI ids. There is list of these pages:
- [Ubuntu](https://cloud-images.ubuntu.com/locator/ec2/)
- [Debian](https://wiki.debian.org/Cloud/AmazonEC2Image)
- [CentOS](https://wiki.centos.org/Cloud/AWS)
- [Rocky Linux](https://rockylinux.org/cloud-images)

## 2. Using AWS-CLI tool
[AWS-CLI](https://aws.amazon.com/cli/) is a powerfull tool for managing AWS services.
The following steps will show you how to find the desired AMI using this tool.
1. Install the tool with `pip install awscli` command
2. Configure the tool with the `aws configure` command. It will require you to enter amazon `access_key_id`,
`secret_access_key` and the output format (json / yaml / text / table)
3. To find AMI id execute
```shell
aws ec2 describe-images \
   --owners 309956199498 \
   --query 'Images[*].[CreationDate,Name,ImageId, Architecture]' \
   --filters "Name=name,Values=RHEL-7.?*GA*" \
   --region us-east-1 \
   --output table | sort -r
```
Where:
- `--owners` - image owner id
- `--query` - describes output values
- `--filters` - AMI filter parameters
- `--region` - [aws region](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html)
- `--output` - output format

Refer to [aws-cli filter usage page](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html),
[describe-images command page](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/describe-images.html)
for detailed command info

List of known owners id:
- Amazon Marketplace - `679593333241`
- RHEL - `309956199498`
- Ubuntu - `099720109477`
- SUSE - `013907871322`
- Debian - `136693071363`
- Rocky Linux - `792107900819`

Also you can get detail information about AMI by executing `aws ec2 describe-images --image-ids ami-07a44bb660e25b065` command.
