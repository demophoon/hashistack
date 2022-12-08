data_dir = "${_context_dir}/data"
bind_addr = "0.0.0.0"

advertise {
  http = "0.0.0.0"
}

server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = true

  cni_path = "${_context_dir}/cni/bin"

  host_volume "waypoint-server" {
    path = "${_context_dir}/volumes/server"
  }
  host_volume "waypoint-runner" {
    path = "${_context_dir}/volumes/runner"
  }
}

plugin "docker" { }

consul {
  address = "127.0.0.1:8500"
}

vault {
  enabled = true
  address = "http://127.0.0.1:8200"
  token = "${_vault_token}"
}
