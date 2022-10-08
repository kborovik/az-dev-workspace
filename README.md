# About

The project solves the problem "It works on my workstation" by creating identical development environments in Azure cloud VMs for all developers working on the application. The idea is very similar to [Github Codespaces](https://github.com/features/codespaces) and allows access to application dependencies (database, file shares) unavailable over the Internet.

The Development environment is 95% matching Staging and Production environments if deployed in VMs and 90% in the Kubernetes cluster.

[Visual Studio Code Remote SSH](https://code.visualstudio.com/docs/remote/ssh) extension allows open a remote source code folder on any remote virtual machine with a running SSH server and take full advantage of VS Code's feature set.

![Visual Studio Code Remote SSH](https://lab5.ca/vscode-ssh.png)

## How to access PinkTree development workspace

- Get SSH private key from Azure Portal

- Add SSH private key to local machine

```
export GITHUB_USER="kborovik"
```

```
cp pinktree-${GITHUB_USER}.key ~/.ssh/pinktree-${GITHUB_USER}.key && chmod 400 ~/.ssh/pinktree-${GITHUB_USER}.key
```

- Add Azure host record to SSH config

```
cat <<EOF | tee -a ~/.ssh/config
Host pinktree-${GITHUB_USER}
  HostName pinktree-${GITHUB_USER}.canadacentral.cloudapp.azure.com
  User ${GITHUB_USER}
  IdentityFile ~/.ssh/pinktree-${GITHUB_USER}.key
EOF
```

- Test SSH connectivity

```
ssh pinktree-${GITHUB_USER}
```

# How to setup PinkTree development workspace

## GitHub Setup

GitHub CLI manual: https://cli.github.com/manual/index

```
gh auth login
```

```
kborovik@pinktree-kborovik ~
(0) > gh auth login
? What account do you want to log into? GitHub.com
? What is your preferred protocol for Git operations? HTTPS
? Authenticate Git with your GitHub credentials? Yes
? How would you like to authenticate GitHub CLI? Login with a web browser

! First copy your one-time code: 4A8C-546D
Press Enter to open github.com in your browser...
! Failed opening a web browser at https://github.com/login/device
  exec: "xdg-open,x-www-browser,www-browser,wslview": executable file not found in $PATH
  Please try entering the URL in your browser manually
```

- Open https://github.com/login/device in the browser
- Enter `one-time code`
- Check authentication status

```
gh auth status
```

```
kborovik@pinktree-kborovik ~
(0) > gh auth status
github.com
  ✓ Logged in to github.com as kborovik (/home/kborovik/.config/gh/hosts.yml)
  ✓ Git operations for github.com configured to use https protocol.
  ✓ Token: *******************
```

- Clone PinkTree repo

```
gh repo clone kborovik/pinktree

```

```
kborovik@pinktree-kborovik ~
(0) > gh repo clone kborovik/pinktree
Cloning into 'pinktree'...
remote: Enumerating objects: 1786, done.
remote: Counting objects: 100% (73/73), done.
remote: Compressing objects: 100% (31/31), done.
remote: Total 1786 (delta 60), reused 43 (delta 42), pack-reused 1713
Receiving objects: 100% (1786/1786), 8.41 MiB | 28.81 MiB/s, done.
Resolving deltas: 100% (349/349), done.
```

## Set APP_ENV

Export `APP_ENV` (application environment) variable. Use your ${GITHUB_USER} for personal APP_ENV. This will allow creation of 100% isolated development environment. APP_ENV names `STG` and `PRD` are reserved for Github Actions pipeline.

```
export APP_ENV="<my-github-handle>"
```

## Create Master password

Create Master Password (master_key) to encrypt/decrypt deployment secrets.

```
mkdir -p ${HOME}/.secrets/$(APP_NAME) && echo "myBigPassword" > ${HOME}/.secrets/$(APP_NAME)/${APP_ENV}
```

## Create secrets file

```
touch $(secrets_enc) && sleep 2 && echo "mssql_pass := ChangeMe!" > $(secrets_txt) && make encrypt
```

## Git commit secrets file

```
git add secrets/${APP_ENV}.enc && git commit --message='add secrets file'
```

## View settings

```
make
```

```
#######################################################################
#
# initialize project                 : make init
# remove all data                    : make clean
# start local Docker Compose DEV env : make start
# stop local Docker Compose DEV env  : make stop
# view DEV env status                : make status
# view DEV env logs                  : make logs
# PHP container shell                : make shell-php
# MSSQL container shell              : make shell-mssql
# view Docker Compose config         : make config
# MSSQL DB backup to local disk      : make backup-local
# MSSQL DB backup to Azure blob      : make backup-azure
# MSSQL DB restore to local disk     : make restore-local
# MSSQL DB restore to Azure blob     : make restore-azure
#
#######################################################################
#
# - APP_ENV:             : kborovik
# - master_key_file:     : /home/kborovik/.secrets/pinktree/kborovik
# - secrets_enc:         : /home/kborovik/github/az-dev-workspace/secrets/kborovik.enc
# - ARM_TENANT_ID:       : <arm-tenant-id>
# - ARM_SUBSCRIPTION_ID: : <arm-subscription-id>
# - AZURE_STORAGE_KEY:   : <azure-storage-key>
# - endpoint_dns:        : http://pinktree-kborovik.pinktree.az
# - endpoint_ip:         : 10.128.0.5
# - mssql_user:          : sa
# - mssql_pass:          : <mssql-password>
#
#######################################################################

```

# How to add secrets

All variables in Makefile with empty values (such as `mssql_pass ?=`) pulled from `secrets/${APP_ENV}.enc` every time `make` runs. **`make` output should not have empty values.**

To add secret to the `secrets` storage:

- Decrypt APP_ENV secrets

```
make decrypt
```

- You should see the text version of the encrypted files

```
tree secrets/

secrets/
├── kborovik.enc
└── kborovik.txt
```

- Edit decrypted file `secrets/${APP_ENV}.txt` by adding VARs (example: `mssql_pass := 1BlueCat@`)

```
echo -e "mssql_pass := 1BlueCat@" >> secrets/${APP_ENV}.txt
```

- Encrypt APP_ENV secrets

```
make encrypt
```

- Git commit updated secrets

```
git add secrets/kborovik.enc && git commit -m "update secrets"
```

- View project configuration. All variables must be set.

```
make
```

# How to use PinkTree App development workspace

## Run PinkTree App first time

To initialize PinkTree development workspace

```
make init
```

`make init` will:

- Build App Docker container
- Download MSSQL backup from Azure
- Restore MSSQL DB
- Start Docker-Compose application

## Every day commands

To view PinkTree application settings

```
make
```

To start PinkTree application

```
make start
```

To stop PinkTree application

```
make stop
```

To get list of all `make` targets

```
make help
```

# How to reset PinkTree development workspace

To reset PinkTree development workspace

```
make clean && make init
```

To force-rebuild PinkTree Docker image

```
make docker-build-force
```
