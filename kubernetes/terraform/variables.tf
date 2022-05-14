variable token {
  description = "OAuth"
}
variable cloud_id {
  description = "Cloud"
}
variable folder_id {
  description = "Folder"
}
variable zone {
  description = "Zone"
  default = "ru-central1-a"
}
variable region {
  description = "Region"
  default = "ru-central1"
}
variable public_key_path {
  description = "Path to the public key used for ssh access"
}
variable private_key_path {
  description = "Path to the private key used for ssh access"
}
variable subnet_id {
  description = "Subnet"
}
variable service_account_key_file {
  description = "key .json"
}
variable count_of_instances {
  description = "Count of instances"
  default     = 1
}
