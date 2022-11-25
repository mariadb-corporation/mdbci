# frozen_string_literal: true

require_relative '../../services/gcp_service'
require_relative '../../services/aws_service'

# Class allows to list and destroy additional cloud resources such as disks (volumes),
# key pairs and security groups
class UnusedCloudResourcesManager
  # Time (in days) after which an unattached resource is considered unused
  DEFAULT_RESOURCE_EXPIRATION_THRESHOLD_DAYS = 1

  def initialize(gcp_service, aws_service, threshold_days = DEFAULT_RESOURCE_EXPIRATION_THRESHOLD_DAYS)
    @gcp_service = gcp_service
    @aws_service = aws_service
    if threshold_days <= 0
      threshold_days = DEFAULT_RESOURCE_EXPIRATION_THRESHOLD_DAYS
    end
    @resource_expiration_threshold = threshold_days
  end

  def list_unused_disks
    gcp_disks = @gcp_service.list_unused_disks(@resource_expiration_threshold)
    aws_disks = @aws_service.list_unused_volumes(@resource_expiration_threshold)
    {
      gcp: gcp_disks,
      aws: aws_disks
    }
  end

  def delete_unused_disks
    @gcp_service.delete_unused_disks(@resource_expiration_threshold)
    @aws_service.delete_unused_volumes(@resource_expiration_threshold)
  end

  def list_unused_aws_key_pairs
    @aws_service.list_unused_key_pairs(@resource_expiration_threshold)
  end

  def delete_unused_aws_key_pairs
    @aws_service.delete_unused_key_pairs(@resource_expiration_threshold)
  end

  def list_unused_aws_security_groups
    @aws_service.list_unused_security_groups(@resource_expiration_threshold)
  end

  def delete_unused_aws_security_groups
    @aws_service.delete_unused_security_groups(@resource_expiration_threshold)
  end
end
