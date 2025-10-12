locals {
  node_groups_with_autoscaling = [for name, group in var.node_groups : name if can(group.autoscaling_policy)]

  node_groups_with_ram_policy = [
    for name in local.node_groups_with_autoscaling :
    name if can(var.node_groups[name].autoscaling_policy.attach_ram_policy)
  ]

  node_groups_with_cpu_policy = [
    for name in local.node_groups_with_autoscaling :
    name if can(var.node_groups[name].autoscaling_policy.attach_cpu_policy)
  ]

  node_groups_with_custom_policy = [
    for name in local.node_groups_with_autoscaling :
    name if can(var.node_groups[name].autoscaling_policy.custom_policy)
  ]

  custom_policies_map = merge([
    for node_group_name in toset(local.node_groups_with_custom_policy) : {
      for policy_name, policy_data in var.node_groups[node_group_name].autoscaling_policy.custom_policy :
      "${node_group_name}-${policy_name}" => {
        node_group_name = node_group_name
        policy_name     = policy_name
        policy_data     = policy_data
      }
    }
  ]...)
}

resource "aws_autoscaling_policy" "cpu" {
  for_each = toset(local.node_groups_with_cpu_policy)

  name                   = "eks-cpu-scaling"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = module.eks.eks_managed_node_groups[each.key].node_group_autoscaling_group_names[0]

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = try(var.default_asg_values.cpu.target_value, 70)
  }
}

resource "aws_autoscaling_policy" "ram" {
  for_each = toset(local.node_groups_with_ram_policy)

  name                   = "eks-ram-scaling"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = module.eks.eks_managed_node_groups[each.key].node_group_autoscaling_group_names[0]

  target_tracking_configuration {
    customized_metric_specification {
      metric_name = try(var.default_asg_values.ram.cloudwatch_metric_name, "MEM_USED_PERCENT")
      namespace   = try(var.default_asg_values.ram.cloudwatch_namespace, "EKS/${var.name}")
      statistic   = "Average"

      metric_dimension {
        name  = "AutoScalingGroupName"
        value = module.eks.eks_managed_node_groups[each.key].node_group_autoscaling_group_names[0]
      }
    }
    target_value = try(var.default_asg_values.ram.target_value, 70)
  }
}

resource "aws_autoscaling_policy" "custom" {
  for_each = local.custom_policies_map

  name                   = try(each.value.policy_name, each.key)
  autoscaling_group_name = module.eks.eks_managed_node_groups[each.value.node_group_name].node_group_autoscaling_group_names[0]

  adjustment_type           = try(each.value.policy_data.adjustment_type, null)
  policy_type               = try(each.value.policy_data.policy_type, null)
  estimated_instance_warmup = try(each.value.policy_data.estimated_instance_warmup, null)
  cooldown                  = try(each.value.policy_data.cooldown, null)
  min_adjustment_magnitude  = try(each.value.policy_data.min_adjustment_magnitude, null)
  metric_aggregation_type   = try(each.value.policy_data.metric_aggregation_type, null)
  scaling_adjustment        = try(each.value.policy_data.scaling_adjustment, null)

  dynamic "step_adjustment" {
    for_each = try(each.value.policy_data.step_adjustment, [])
    content {
      scaling_adjustment          = step_adjustment.value.scaling_adjustment
      metric_interval_lower_bound = try(step_adjustment.value.metric_interval_lower_bound, null)
      metric_interval_upper_bound = try(step_adjustment.value.metric_interval_upper_bound, null)
    }
  }

  dynamic "target_tracking_configuration" {
    for_each = try([each.value.policy_data.target_tracking_configuration], [])
    content {
      target_value     = target_tracking_configuration.value.target_value
      disable_scale_in = try(target_tracking_configuration.value.disable_scale_in, null)

      dynamic "predefined_metric_specification" {
        for_each = try([target_tracking_configuration.value.predefined_metric_specification], [])
        content {
          predefined_metric_type = predefined_metric_specification.value.predefined_metric_type
          resource_label         = try(predefined_metric_specification.value.resource_label, null)
        }
      }

      dynamic "customized_metric_specification" {
        for_each = try([target_tracking_configuration.value.customized_metric_specification], [])

        content {
          dynamic "metric_dimension" {
            for_each = try([customized_metric_specification.value.metric_dimension], [])

            content {
              name  = metric_dimension.value.name
              value = metric_dimension.value.value
            }
          }

          metric_name = try(customized_metric_specification.value.metric_name, null)

          dynamic "metrics" {
            for_each = try(customized_metric_specification.value.metrics, [])

            content {
              expression = try(metrics.value.expression, null)
              id         = metrics.value.id
              label      = try(metrics.value.label, null)

              dynamic "metric_stat" {
                for_each = try([metrics.value.metric_stat], [])

                content {
                  dynamic "metric" {
                    for_each = try([metric_stat.value.metric], [])

                    content {
                      dynamic "dimensions" {
                        for_each = try(metric.value.dimensions, [])

                        content {
                          name  = dimensions.value.name
                          value = dimensions.value.value
                        }
                      }

                      metric_name = metric.value.metric_name
                      namespace   = metric.value.namespace
                    }
                  }

                  period = try(metric_stat.value.period, null)
                  stat   = metric_stat.value.stat
                  unit   = try(metric_stat.value.unit, null)
                }
              }

              return_data = try(metrics.value.return_data, null)
            }
          }

          namespace = try(customized_metric_specification.value.namespace, null)
          statistic = try(customized_metric_specification.value.statistic, null)
          unit      = try(customized_metric_specification.value.unit, null)
        }
      }
    }
  }

  dynamic "predictive_scaling_configuration" {
    for_each = try([each.value.policy_data.predictive_scaling_configuration], [])
    content {
      max_capacity_breach_behavior = try(predictive_scaling_configuration.value.max_capacity_breach_behavior, null)
      max_capacity_buffer          = try(predictive_scaling_configuration.value.max_capacity_buffer, null)
      mode                         = try(predictive_scaling_configuration.value.mode, null)
      scheduling_buffer_time       = try(predictive_scaling_configuration.value.scheduling_buffer_time, null)

      dynamic "metric_specification" {
        for_each = try([predictive_scaling_configuration.value.metric_specification], [])
        content {
          target_value = metric_specification.value.target_value

          dynamic "predefined_load_metric_specification" {
            for_each = try([metric_specification.value.predefined_load_metric_specification], [])
            content {
              predefined_metric_type = predefined_load_metric_specification.value.predefined_metric_type
              resource_label         = predefined_load_metric_specification.value.resource_label
            }
          }

          dynamic "predefined_metric_pair_specification" {
            for_each = try([metric_specification.value.predefined_metric_pair_specification], [])
            content {
              predefined_metric_type = predefined_metric_pair_specification.value.predefined_metric_type
              resource_label         = predefined_metric_pair_specification.value.resource_label
            }
          }

          dynamic "predefined_scaling_metric_specification" {
            for_each = try([metric_specification.value.predefined_scaling_metric_specification], [])
            content {
              predefined_metric_type = predefined_scaling_metric_specification.value.predefined_metric_type
              resource_label         = predefined_scaling_metric_specification.value.resource_label
            }
          }
        }
      }
    }
  }
}
