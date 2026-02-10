#!/bin/bash

# ==============================================================================
# SCRIPT DE INSTALAÇÃO: Zabbix Agent 2
# COMPATIBILIDADE INICIAL: CentOS 7 (EOL)
# DESENVOLVIDO POR: Patryck Pinhal
# DATA: 10/02/2026
# ==============================================================================

# --- FUNÇÃO: LOGGING ---
# Exibe mensagens formatadas para facilitar a leitura no terminal
log_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[32m[SUCESSO]\e[0m $1"; }
log_error() { echo -e "\e[31m[ERRO]\e[0m $1"; }
log_warn() { echo -e "\e[33m[AVISO]\e[0m $1"; }

# --- VALIDAR USUÁRIO ROOT ---
if [ "$EUID" -ne 0 ]; then
  log_error "Por favor, execute este script como root ou usando sudo."
  exit 1
fi

# --- 1. IDENTIFICAÇÃO DO SISTEMA OPERACIONAL ---
# Aqui começamos a preparação para suportar outros Linux no futuro
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
else
    log_error "Não foi possível identificar o Sistema Operacional."
    exit 1
fi

log_info "Sistema identificado: $PRETTY_NAME"

# --- 2. LÓGICA ESPECÍFICA PARA CENTOS 7 ---
if [[ "$OS_NAME" == "centos" && "$OS_VERSION" == "7" ]]; then
    log_success "CentOS 7 detectado! Iniciando procedimentos de correção EOL (Vault)..."

    # Correção dos mirrors para o Vault oficial (essencial após o EOL do CentOS 7)
    sed -i 's/mirrorlist.centos.org/vault.centos.org/g' /etc/yum.repos.d/CentOS-*.repo
    sed -i 's/^#baseurl=http:\/\/mirror.centos.org/baseurl=http:\/\/vault.centos.org/g' /etc/yum.repos.d/CentOS-*.repo
    sed -i 's/^#.*baseurl=http:\/\/mirror.centos.org/baseurl=http:\/\/vault.centos.org/g' /etc/yum.repos.d/CentOS-*.repo

    # Instalação do Repositório Oficial Zabbix 7.0 LTS
    rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/7/x86_64/zabbix-release-7.0-1.el7.noarch.rpm --force &> /dev/null
    yum clean all &> /dev/null

    # Instalação do Agente
    log_info "Instalando Zabbix Agent 2..."
    yum install zabbix-agent2 -y
    
else
    # --- PREPARAÇÃO PARA FUTURAS DISTROS ---
    log_warn "Este script ainda não possui automação para $OS_NAME $OS_VERSION."
    log_warn "Acesse o GitHub para contribuir com novos instaladores."
    exit 1
fi

# --- 3. COLETA DE PARÂMETROS ---
echo ""
read -p ">> Digite o IP do Zabbix Server: " ZBX_IP
read -p ">> Digite o Hostname para o Zabbix [Sugestão: $(hostname)]: " ZBX_HOSTNAME
ZBX_HOSTNAME=${ZBX_HOSTNAME:-$(hostname)}

# --- 4. CONFIGURAÇÃO DO AGENTE ---
CONF_FILE="/etc/zabbix/zabbix_agent2.conf"

if [ -f "$CONF_FILE" ]; then
    log_info "Aplicando configurações em $CONF_FILE..."
    
    # Substituições usando sed
    sed -i "s/^Server=127.0.0.1/Server=$ZBX_IP/" $CONF_FILE
    sed -i "s/^ServerActive=127.0.0.1/ServerActive=$ZBX_IP/" $CONF_FILE
    sed -i "s/^Hostname=Zabbix server/Hostname=$ZBX_HOSTNAME/" $CONF_FILE
    
    # Ativação do serviço
    systemctl enable zabbix-agent2 &> /dev/null
    systemctl restart zabbix-agent2
else
    log_error "Arquivo de configuração não encontrado em $CONF_FILE"
    exit 1
fi

# --- 5. VERIFICAÇÃO FINAL ---
echo "-----------------------------------------------------"
if systemctl is-active --quiet zabbix-agent2; then
    log_success "Zabbix Agent 2 instalado e rodando com sucesso!"
    log_info "IP do Servidor: $ZBX_IP"
    log_info "Hostname Zabbix: $ZBX_HOSTNAME"
    log_info "Porta 10050 aberta localmente."
else
    log_error "Falha ao iniciar o agente. Verifique os logs."
fi
echo "-----------------------------------------------------"