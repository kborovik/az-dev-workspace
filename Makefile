.ONESHELL:
.SILENT:
.EXPORT_ALL_VARIABLES:

SHELL := /bin/bash

###############################################################################
# Master Key and Application environment settings
###############################################################################
APP_ENV ?= kborovik
APP_NAME := pinktree
master_key_file := $(shell ls ${HOME}/.secrets/$(APP_NAME)/${APP_ENV})
master_key ?= $(strip $(file < $(master_key_file)))

###############################################################################
# Azure Variables
###############################################################################
ARM_TENANT_ID ?=
ARM_SUBSCRIPTION_ID ?=

AZURE_STORAGE_ACCOUNT := pinktree2mssql
AZURE_STORAGE_AUTH_MODE := key
AZURE_STORAGE_KEY ?= 
AZURE_STORAGE_CONNECTION_STRING ?= 

###############################################################################
# Docker Compose variables
###############################################################################
COMPOSE_PROJECT_NAME := $(APP_NAME)

###############################################################################
# MSSQL Variables
###############################################################################
mssql_user ?= sa
mssql_pass ?=

settings: secrets-clean help
	echo "#######################################################################"
	echo "#"
	echo "# - APP_ENV:             : $(APP_ENV)"
	echo "# - master_key_file:     : $(master_key_file)"
	echo "# - secrets_enc:         : $(abspath $(secrets_enc))"
	echo "# - ARM_TENANT_ID:       : $(ARM_TENANT_ID)"
	echo "# - ARM_SUBSCRIPTION_ID: : $(ARM_SUBSCRIPTION_ID)"
	echo "# - AZURE_STORAGE_KEY:   : $(AZURE_STORAGE_KEY)"
	echo "# - endpoint_dns:        : http://pinktree-$(APP_ENV).pinktree.az"
	echo "# - endpoint_ip:         : "
	echo "# - mssql_user:          : $(mssql_user)"
	echo "# - mssql_pass:          : $(mssql_pass)"
	echo "#"
	echo "#######################################################################"

help: secrets-clean
	echo "#######################################################################"
	echo "#"
	echo "# initialize project                 : make init"
	echo "# remove all data                    : make clean"
	echo "# start local Docker Compose DEV env : make start"
	echo "# stop local Docker Compose DEV env  : make stop"
	echo "# view DEV env status                : make status"
	echo "# view DEV env logs                  : make logs"
	echo "# PHP container shell                : make shell-php"
	echo "# MSSQL container shell              : make shell-mssql"
	echo "# view Docker Compose config         : make config"
	echo "# MSSQL DB backup to local disk      : make backup-local"
	echo "# MSSQL DB backup to Azure blob      : make backup-azure"
	echo "# MSSQL DB restore to local disk     : make restore-local"
	echo "# MSSQL DB restore to Azure blob     : make restore-azure"
	echo "#"
	echo "#######################################################################"

###############################################################################
# Main targets
###############################################################################
all: clean init

init: build mssql-restore-azure start restore-local status

start: docker-up

stop: docker-down

backup-local: mssql-backup-local

backup-azure: mssql-backup-azure

restore-local: mssql-restore-local mssql-status

restore-azure: mssql-restore-azure mssql-status

build: docker-build

status: docker-status mssql-status

logs: docker-logs

config: docker-config

clean: docker-clean mssql-clean

###############################################################################
# Secrets. Variable values stored in secrets.enc
###############################################################################
secrets_enc := secrets/$(APP_ENV).enc
secrets_txt := secrets/$(APP_ENV).txt

$(secrets_txt):
	openssl enc -d -aes128 -pbkdf2 -base64 -in $(secrets_enc) -pass pass:$(master_key) -out $@ || shred -uf $(secrets_txt)

$(secrets_enc): $(secrets_txt)
	openssl enc -aes128 -pbkdf2 -base64 -in $(secrets_txt) -pass pass:$(master_key) -out $@ && shred -uf $(secrets_txt)

decrypt: $(secrets_txt)

encrypt: $(secrets_enc)

secrets-clean:
	-shred -uf $(secrets_txt)

include $(secrets_txt)

###############################################################################
# Docker Compose
###############################################################################
docker-up: mssql-folders
	$(call header,Start pinktree)
	docker compose up --detach

docker-down: secrets-clean
	$(call header,Stop pinktree)
	docker compose down

docker-build: docker-down
	$(call header,Re-Build Docker Image)
	docker compose build

docker-build-force: docker-down
	$(call header,Re-Build Docker Image)
	docker compose build --no-cache

docker-logs: secrets-clean
	$(call header,Show Docker Logs)
	docker compose logs

docker-config: secrets-clean
	$(call header,Show Docker Compose Config)
	docker compose config

docker-status: secrets-clean
	$(call header,Show Docker Status)
	docker compose ps
	$(call header,Show Docker Top)
	docker compose top

docker-top: secrets-clean
	$(call header,Show Docker Top)
	docker compose top

docker-clean: docker-down
	$(call header,Prune Docker Images & Containers)
	docker image prune --force
	docker container prune --force

shell-php: secrets-clean
	docker compose exec php bash

shell-mssql: secrets-clean
	docker compose exec mssql bash


###############################################################################
# MS SQL
###############################################################################
mssql_folders := mssql/data mssql/secrets mssql/log mssql/backup

mssql-folders:
	mkdir -p -m 1777 $(mssql_folders)

mssql-setup: secrets-clean
	$(call header,Setup MSSQL)
	sleep 10
	docker compose exec mssql /opt/mssql-tools/bin/sqlcmd -C -W -S localhost -U $(mssql_user) -P $(mssql_pass) -i /var/opt/mssql/scripts/mssql-setup.sql

mssql-backup-local: secrets-clean
	$(call header,Backup MSSQL Local)
	docker compose exec mssql /opt/mssql-tools/bin/sqlcmd -C -W -S localhost -U $(mssql_user) -P $(mssql_pass) -i /var/opt/mssql/scripts/backup-database.sql

mssql-backup-azure:
	$(call header,Backup MSSQL Azure)
	az storage copy --source $(abspath mssql/backup/$(APP_NAME).bak) --destination https://$(AZURE_STORAGE_ACCOUNT).blob.core.windows.net/mssql-backups/$(APP_NAME)-$(APP_ENV).bak --put-md5

mssql-restore-azure: mssql-folders
	$(call header,Restore MSSQL Azure)
	az storage copy --source https://$(AZURE_STORAGE_ACCOUNT).blob.core.windows.net/mssql-backups/$(APP_NAME)-$(APP_ENV).bak --destination $(abspath mssql/backup/$(APP_NAME).bak)
	chmod 1666 mssql/backup/$(APP_NAME).bak

mssql-restore-local: mssql-setup
	$(call header,Restore MSSQL DB)
	docker compose exec mssql /opt/mssql-tools/bin/sqlcmd -C -W -S localhost -U $(mssql_user) -P $(mssql_pass) -i /var/opt/mssql/scripts/restore-database.sql

mssql-status: secrets-clean
	$(call header,Show MSSQL Status)
	docker compose exec mssql /opt/mssql-tools/bin/sqlcmd -C -y 15 -Y 15 -S localhost -U $(mssql_user) -P $(mssql_pass) -i /var/opt/mssql/scripts/backup-status.sql

mssql-clean: docker-down
	$(call header,Remove MSSQL Files)
	-rm -rf mssql/log mssql/data mssql/secrets mssql/backup

###############################################################################
# Azure DEV environment
###############################################################################
az_dev_resource_group := $(APP_NAME)-dev
az_dev_storage_account := $(APP_NAME)2dev
az_dev_subnet := workstation
az_dev_subnet_address := 10.128.0.0/24
az_dev_vm_size := Standard_B2ms
az_dev_vnet := $(APP_NAME)-dev
az_dev_vnet_address := 10.128.0.0/16
az_location := canadacentral
az_os_image := Canonical:0001-com-ubuntu-server-focal:20_04-lts-gen2:latest
az_ssh_key_kborovik ?=
az_user := kborovik

az-dev-set-subscription: secrets-clean
	$(call header,Set Azure Subscription)
	az account set --subscription $(ARM_SUBSCRIPTION_ID)

az-dev-resource-group: az-dev-set-subscription
	$(call header,Create Azure Resource Group)
	az group create --location $(az_location) --resource-group $(az_dev_resource_group) --output none

az-dev-vnet: az-dev-resource-group
	$(call header,Create Azure vNet + Subnet)
	az network vnet create --name $(az_dev_vnet) --resource-group $(az_dev_resource_group) --address-prefixes $(az_dev_vnet_address) --subnet-name $(az_dev_subnet) --subnet-prefixes $(az_dev_subnet_address) --output none

az-dev-storage-account: az-dev-resource-group
	$(call header,Create Azure Storage Account)
	az storage account create --name $(az_dev_storage_account) --resource-group $(az_dev_resource_group) --kind StorageV2 --sku Standard_LRS --access-tier Hot --allow-blob-public-access false --output none

az-dev-storage-container: az-dev-storage-account
	$(call header,Create Azure Blob Container)
	az storage container create --name mssql --resource-group $(az_dev_resource_group) --account-name $(az_dev_storage_account) --output none

az-dev-vm-create: az-dev-resource-group az-dev-vnet
	$(call header,Create Azure Virtual Machines)
	$(call az-dev-vm-create,kborovik,10.128.0.5)

# $(call az-vm-create,github_id,private_ip)
define az-dev-vm-create
az network nsg create --name $(APP_NAME)-$(1) --resource-group $(az_dev_resource_group) --only-show-errors --output none
az network nsg rule create --name allow-ssh --resource-group $(az_dev_resource_group) --nsg-name $(APP_NAME)-$(1) --priority 1000 --protocol TCP --destination-port-ranges 22 --output none
az network nsg rule create --name allow-openvpn --resource-group $(az_dev_resource_group) --nsg-name $(APP_NAME)-$(1) --priority 1001 --protocol UDP --destination-port-ranges 1194 --output none
az vm create --name $(APP_NAME)-$(1) --resource-group $(az_dev_resource_group) --admin-username $(1) --private-ip-address $(2) --nsg $(APP_NAME)-$(1) --public-ip-address-dns-name $(APP_NAME)-$(1) --image $(az_os_image) --nic-delete-option Delete --os-disk-delete-option Detach --os-disk-size-gb 32 --public-ip-sku Basic --public-ip-address-allocation static --size $(az_dev_vm_size) --vnet-name $(az_dev_vnet) --subnet $(az_dev_subnet) --user-data azure/dev-workstation-init.sh --ssh-key-values azure/ssh/$(APP_NAME)-$(1).pub
endef

###############################################################################
# Deployment Tests
###############################################################################

###############################################################################
# Error Checks
###############################################################################
prompt: settings
	echo
	read -p "Continue deployment? (yes/no): " INP
	if [ "$${INP}" != "yes" ]; then 
	  echo "Deployment aborted"
	  exit 100
	fi

define header
echo
echo "########################################################################"
echo "# $(1)"
echo "########################################################################"
endef

ifeq ($(APP_ENV),)
$(error APP_ENV is not set. export APP_ENV=<app-env-name>)
endif

ifeq ($(wildcard $(master_key_file)),)
$(error Master Key file not found. Run 'mkdir -p ${HOME}/.secrets/$(APP_NAME) && echo "myBigPassword" > ${HOME}/.secrets/$(APP_NAME)/${APP_ENV}')
endif

ifeq ($(strip $(master_key)),)
$(error master_key is empty. Add password to file ${HOME}/.secrets/$(APP_NAME)/$(APP_ENV))
endif

ifeq ($(wildcard $(secrets_enc)),)
$(error File '$(secrets_enc)' not found. Run `touch $(secrets_enc) && sleep 2 && echo "mssql_pass := ChangeMe!" > $(secrets_txt) && make encrypt`)
endif

ifeq ($(shell which az),)
$(error Unable to locate command 'azure cli'. https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
endif

ifeq ($(shell which docker),)
$(error Unable to locate command 'docker'. https://docs.docker.com/get-docker/)
endif
