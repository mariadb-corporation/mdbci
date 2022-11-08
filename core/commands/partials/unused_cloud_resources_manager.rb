# frozen_string_literal: true

require_relative '../../services/gcp_service'
require_relative '../../services/aws_service'

# Class allows to list and destroy additional cloud resources such as disks (volumes),
# key pairs and security groups
class UnusedCloudResourcesManager
  # Time (in days) after which an unattached resource is considered unused
  RESOURCE_EXPIRATION_THRESHOLD_DAYS = 1

  def initialize(gcp_service, aws_service)
    @gcp_service = gcp_service
    @aws_service = aws_service
  end

  def list_unused_disks
    gcp_disks = @gcp_service.list_unused_disks(RESOURCE_EXPIRATION_THRESHOLD_DAYS)
    aws_disks = []
    {
      gcp: gcp_disks,
      aws: aws_disks
    }
  end

  def delete_unused_disks
    @gcp_service.delete_unused_disks(RESOURCE_EXPIRATION_THRESHOLD_DAYS)
  end

end
