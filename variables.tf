variable "primary_sqlmi" {
  description = "The Primary SQL MI instance details"
  type        = map(string)
}

variable "secondary_sqlmi" {
  description = "The Secondary (Failover) SQL MI instance details"
  type        = map(string)
}

variable "location_pri" {
  description = "Primary Azure region location for all resources"
}

variable "location_sec" {
  description = "Secondary Azure region location for all resources"
}

variable "rg_pri" {
  description = "Primary Resource Group name for all resources"
}

variable "rg_sec" {
  description = "Secondary Resource Group name for all resources"
}