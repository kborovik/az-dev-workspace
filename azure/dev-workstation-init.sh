#! /bin/env bash

export DEBIAN_FRONTEND noninteractive

# add Docker apt repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/docker.list
deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable
EOF

# add OpenVPN apt repo
curl -fsSL https://as-repository.openvpn.net/as-repo-public.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/openvpn-as-repo.list
deb [arch=$(dpkg --print-architecture)] http://as-repository.openvpn.net/as/debian $(lsb_release -cs) main
EOF

# add Microsoft apt repo
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/azure-cli.list
deb [arch=$(dpkg --print-architecture)] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main
EOF

# add GitHub apt repo
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg
cat <<EOF | tee tee /etc/apt/sources.list.d/github-cli.list
deb [arch=$(dpkg --print-architecture)] https://cli.github.com/packages stable main
EOF

apt remove -y docker docker-engine docker.io containerd runc

apt update -y

apt upgrade -y

apt install -y \
  azure-cli \
  containerd.io \
  docker-ce \
  docker-ce-cli \
  docker-compose-plugin \
  gh \
  jq \
  make \
  net-tools \
  openvpn-as \
  tree

# configure Docker
usermod -aG docker "$(id --user 1000 --name)"

cat <<EOF | tee /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://mirror.gcr.io"
  ],
  "features": {
    "buildkit": true
  }
}
EOF

systemctl restart docker.service

# configure OpenVPN
external_ip=$(curl -sSL http://ipinfo.io | grep '"ip"' | cut -d'"' -f4)

/usr/local/openvpn_as/scripts/sacli --key "host.name" --value "${external_ip}" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "vpn.client.routing.reroute_gw" --value "false" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.private_network.0" --value "10.128.0.0/24" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "vpn.server.dhcp_option.domain" --value "pinktree.az" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "vpn.server.dhcp_option.adapter_domain_suffix" --value "pinktree.az" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "vpn.client.routing.reroute_dns" --value "true" ConfigPut

cat <<'EOF' | tee /usr/local/bin/openvpn-create-user.sh
#!/bin/env bash
openvpn_user_name=${1}
openvpn_auth_file="${HOME}"/"${openvpn_user_name}".ovpn
_usage() {
  echo "Usage: $(basename "$0") <openvpn_user_name>"
  exit 1
}
[[ -z "${openvpn_user_name}" ]] && _usage
sudo /usr/local/openvpn_as/scripts/sacli --user "${openvpn_user_name}" AutoGenerateOnBehalfOf
sudo /usr/local/openvpn_as/scripts/sacli --user "${openvpn_user_name}" RemoveLocalPassword
sudo /usr/local/openvpn_as/scripts/sacli --user "${openvpn_user_name}" --key "type" --value "user_connect" UserPropPut
sudo /usr/local/openvpn_as/scripts/sacli --user "${openvpn_user_name}" --key "prop_autologin" --value "true" UserPropPut
sudo /usr/local/openvpn_as/scripts/sacli --user "${openvpn_user_name}" GetAutologin | tee "${openvpn_auth_file}"
chmod 0600 "${openvpn_auth_file}"
EOF

chmod 755 /usr/local/bin/openvpn-create-user.sh

# Create MSSQL system user
useradd mssql --system --uid 10001 --gid root --no-create-home --comment "MSSQL Service Account"

systemctl reboot
