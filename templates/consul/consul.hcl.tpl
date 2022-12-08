data_dir = "${_context_dir}/data"
log_level = "DEBUG"

server = true
bootstrap_expect = 1

bind_addr = "127.0.0.1"
client_addr = "127.0.0.1"

ui_config {
	enabled = true
}

connect {
	enabled = true
}
ports {
  grpc = 8502
}
enable_central_service_config = true

acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}
