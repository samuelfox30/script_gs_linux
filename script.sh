#!/bin/bash

################################################################################
# SCRIPT DE AUTOMAÇÃO - SERVIDOR WEB
# Descrição: Automatiza a instalação e configuração de um servidor web Apache
#            com template HTML personalizado
# Sistema: Debian
# Autor: [Samuel Raposo Da Gama]
# Data: [11/14/2025]
################################################################################

# ============================================================================
# CONFIGURAÇÕES INICIAIS
# ============================================================================

# Define cores para melhor visualização no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

# Variáveis do sistema
LOG_FILE="/var/log/instalacao_web_$(date +%Y%m%d_%H%M%S).log"
APACHE_DIR="/var/www/html"
BACKUP_DIR="/root/backup_apache_$(date +%Y%m%d_%H%M%S)"

# ============================================================================
# SEÇÃO 1: CONFIGURAÇÕES DO TEMPLATE
# ============================================================================
# ATENÇÃO: Altere aqui a URL do template HTML que será baixado
TEMPLATE_URL="https://www.free-css.com/assets/files/free-css-templates/download/page296/oxer.zip"
TEMPLATE_NAME="template.zip"

# ============================================================================
# SEÇÃO 2: CONFIGURAÇÕES ADICIONAIS DA GS
# ============================================================================
# TODO: ADICIONAR CONFIGURAÇÃO 1 AQUI (durante a GS)
# Exemplo: PORTA_CUSTOMIZADA=8080
# [ESPAÇO RESERVADO PARA CONFIGURAÇÃO 1]


# TODO: ADICIONAR CONFIGURAÇÃO 2 AQUI (durante a GS)
# Exemplo: HABILITAR_SSL=true
# [ESPAÇO RESERVADO PARA CONFIGURAÇÃO 2]


# TODO: ADICIONAR CONFIGURAÇÃO 3 AQUI (durante a GS)
# Exemplo: USUARIO_ADMIN="admin"
# [ESPAÇO RESERVADO PARA CONFIGURAÇÃO 3]


# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

# Função para exibir mensagens formatadas
print_message() {
    local type=$1
    local message=$2
    
    case $type in
        "info")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[INFO] $message" >> "$LOG_FILE"
            ;;
        "success")
            echo -e "${GREEN}[SUCESSO]${NC} $message"
            echo "[SUCESSO] $message" >> "$LOG_FILE"
            ;;
        "warning")
            echo -e "${YELLOW}[AVISO]${NC} $message"
            echo "[AVISO] $message" >> "$LOG_FILE"
            ;;
        "error")
            echo -e "${RED}[ERRO]${NC} $message"
            echo "[ERRO] $message" >> "$LOG_FILE"
            ;;
    esac
}

# Função para verificar se comando foi executado com sucesso
check_status() {
    if [ $? -eq 0 ]; then
        print_message "success" "$1"
        return 0
    else
        print_message "error" "$2"
        exit 1
    fi
}

# Função para criar separador visual
print_separator() {
    echo ""
    echo "=========================================================================="
    echo "$1"
    echo "=========================================================================="
    echo ""
}

# Função para solicitar confirmação do usuário
ask_confirmation() {
    local question=$1
    local response
    
    while true; do
        echo -e "${YELLOW}$question (s/n):${NC} "
        read -r response
        
        case $response in
            [Ss]|[Ss][Ii][Mm])
                return 0
                ;;
            [Nn]|[Nn][Aa][Oo])
                return 1
                ;;
            *)
                echo -e "${RED}Resposta inválida! Digite 's' para sim ou 'n' para não.${NC}"
                ;;
        esac
    done
}

# ============================================================================
# VERIFICAÇÕES INICIAIS
# ============================================================================

print_separator "INICIANDO SCRIPT DE INSTALAÇÃO DO SERVIDOR WEB"

# Verificar se o script está sendo executado como root
print_message "info" "Verificando permissões de administrador..."
if [ "$EUID" -ne 0 ]; then
    print_message "error" "Este script precisa ser executado como root (administrador)!"
    print_message "info" "Execute: sudo bash $0"
    exit 1
fi
print_message "success" "Permissões verificadas com sucesso!"

# Exibir informações do sistema
print_message "info" "Sistema operacional: $(lsb_release -d | cut -f2)"
print_message "info" "Versão do Kernel: $(uname -r)"
print_message "info" "Data/Hora: $(date '+%d/%m/%Y %H:%M:%S')"
print_message "info" "Arquivo de log: $LOG_FILE"

echo ""
print_message "warning" "Este script irá realizar as seguintes operações:"
echo "  1. Atualizar os repositórios do sistema"
echo "  2. Instalar o servidor web Apache2"
echo "  3. Instalar utilitários necessários (wget, unzip, curl)"
echo "  4. Baixar e configurar um template HTML"
echo "  5. Configurar o Apache como serviço ativo"
echo "  6. Aplicar configurações de segurança básicas"
echo ""

# Solicitar confirmação para continuar
if ! ask_confirmation "Deseja continuar com a instalação?"; then
    print_message "warning" "Instalação cancelada pelo usuário."
    exit 0
fi

# ============================================================================
# ETAPA 1: ATUALIZAÇÃO DO SISTEMA
# ============================================================================

print_separator "ETAPA 1: ATUALIZANDO REPOSITÓRIOS DO SISTEMA"

print_message "info" "Atualizando lista de pacotes disponíveis..."
apt-get update >> "$LOG_FILE" 2>&1
check_status "Repositórios atualizados com sucesso!" "Falha ao atualizar repositórios!"

print_message "info" "Atualizando pacotes do sistema (isso pode demorar)..."
apt-get upgrade -y >> "$LOG_FILE" 2>&1
check_status "Sistema atualizado com sucesso!" "Falha ao atualizar o sistema!"

# ============================================================================
# ETAPA 2: INSTALAÇÃO DE DEPENDÊNCIAS
# ============================================================================

print_separator "ETAPA 2: INSTALANDO DEPENDÊNCIAS NECESSÁRIAS"

print_message "info" "Instalando wget (ferramenta para download de arquivos)..."
apt-get install -y wget >> "$LOG_FILE" 2>&1
check_status "wget instalado com sucesso!" "Falha ao instalar wget!"

print_message "info" "Instalando unzip (ferramenta para descompactar arquivos)..."
apt-get install -y unzip >> "$LOG_FILE" 2>&1
check_status "unzip instalado com sucesso!" "Falha ao instalar unzip!"

print_message "info" "Instalando curl (ferramenta para transferência de dados)..."
apt-get install -y curl >> "$LOG_FILE" 2>&1
check_status "curl instalado com sucesso!" "Falha ao instalar curl!"

# ============================================================================
# ETAPA 3: INSTALAÇÃO DO APACHE
# ============================================================================

print_separator "ETAPA 3: INSTALANDO SERVIDOR WEB APACHE2"

print_message "info" "Verificando se o Apache já está instalado..."
if systemctl is-active --quiet apache2; then
    print_message "warning" "Apache já está instalado e em execução!"
    
    if ask_confirmation "Deseja criar backup e reinstalar?"; then
        print_message "info" "Criando backup do diretório atual do Apache..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$APACHE_DIR" "$BACKUP_DIR/" >> "$LOG_FILE" 2>&1
        check_status "Backup criado em: $BACKUP_DIR" "Falha ao criar backup!"
        
        print_message "info" "Parando serviço Apache..."
        systemctl stop apache2 >> "$LOG_FILE" 2>&1
    fi
else
    print_message "info" "Instalando Apache2..."
    apt-get install -y apache2 >> "$LOG_FILE" 2>&1
    check_status "Apache2 instalado com sucesso!" "Falha ao instalar Apache2!"
fi

# ============================================================================
# SEÇÃO 3: APLICAR CONFIGURAÇÃO ADICIONAL 1 DA GS
# ============================================================================
# TODO: INSERIR CÓDIGO PARA CONFIGURAÇÃO 1 AQUI
# Exemplo: Alterar porta padrão do Apache
# print_message "info" "Configurando porta customizada..."
# sed -i "s/Listen 80/Listen $PORTA_CUSTOMIZADA/g" /etc/apache2/ports.conf
# [ESPAÇO RESERVADO PARA IMPLEMENTAÇÃO DA CONFIGURAÇÃO 1]


# ============================================================================
# ETAPA 4: DOWNLOAD E CONFIGURAÇÃO DO TEMPLATE
# ============================================================================

print_separator "ETAPA 4: BAIXANDO E CONFIGURANDO TEMPLATE HTML"

print_message "info" "Limpando diretório web atual..."
rm -rf "${APACHE_DIR:?}"/* >> "$LOG_FILE" 2>&1
check_status "Diretório limpo com sucesso!" "Falha ao limpar diretório!"

print_message "info" "Baixando template HTML da internet..."
cd /tmp || exit 1
wget -O "$TEMPLATE_NAME" "$TEMPLATE_URL" >> "$LOG_FILE" 2>&1
check_status "Template baixado com sucesso!" "Falha ao baixar template!"

print_message "info" "Descompactando template..."
unzip -o "$TEMPLATE_NAME" -d /tmp/template_temp >> "$LOG_FILE" 2>&1
check_status "Template descompactado com sucesso!" "Falha ao descompactar template!"

print_message "info" "Copiando arquivos para o diretório do Apache..."
# Procura por arquivos HTML no diretório descompactado
TEMPLATE_DIR=$(find /tmp/template_temp -type f -name "*.html" -printf '%h\n' | head -n 1)

if [ -n "$TEMPLATE_DIR" ]; then
    cp -r "$TEMPLATE_DIR"/* "$APACHE_DIR/" >> "$LOG_FILE" 2>&1
    check_status "Arquivos copiados para $APACHE_DIR" "Falha ao copiar arquivos!"
else
    print_message "error" "Não foi possível localizar arquivos HTML no template!"
    exit 1
fi

# ============================================================================
# SEÇÃO 4: APLICAR CONFIGURAÇÃO ADICIONAL 2 DA GS
# ============================================================================
# TODO: INSERIR CÓDIGO PARA CONFIGURAÇÃO 2 AQUI
# Exemplo: Habilitar módulos SSL do Apache
# print_message "info" "Habilitando SSL..."
# a2enmod ssl
# a2ensite default-ssl
# [ESPAÇO RESERVADO PARA IMPLEMENTAÇÃO DA CONFIGURAÇÃO 2]


# ============================================================================
# ETAPA 5: CONFIGURAÇÃO DE PERMISSÕES
# ============================================================================

print_separator "ETAPA 5: CONFIGURANDO PERMISSÕES E PROPRIEDADE"

print_message "info" "Ajustando permissões dos arquivos..."
chown -R www-data:www-data "$APACHE_DIR" >> "$LOG_FILE" 2>&1
check_status "Proprietário definido como www-data" "Falha ao definir proprietário!"

chmod -R 755 "$APACHE_DIR" >> "$LOG_FILE" 2>&1
check_status "Permissões configuradas (755)" "Falha ao configurar permissões!"

# ============================================================================
# SEÇÃO 5: APLICAR CONFIGURAÇÃO ADICIONAL 3 DA GS
# ============================================================================
# TODO: INSERIR CÓDIGO PARA CONFIGURAÇÃO 3 AQUI
# Exemplo: Criar arquivo de autenticação básica
# print_message "info" "Configurando autenticação..."
# htpasswd -cb /etc/apache2/.htpasswd $USUARIO_ADMIN senha123
# [ESPAÇO RESERVADO PARA IMPLEMENTAÇÃO DA CONFIGURAÇÃO 3]


# ============================================================================
# ETAPA 6: CONFIGURAÇÃO DO FIREWALL (UFW)
# ============================================================================

print_separator "ETAPA 6: CONFIGURANDO FIREWALL"

print_message "info" "Verificando se o UFW está instalado..."
if ! command -v ufw &> /dev/null; then
    print_message "info" "Instalando UFW (Uncomplicated Firewall)..."
    apt-get install -y ufw >> "$LOG_FILE" 2>&1
    check_status "UFW instalado com sucesso!" "Falha ao instalar UFW!"
fi

print_message "info" "Configurando regras do firewall..."
ufw allow 'Apache Full' >> "$LOG_FILE" 2>&1
check_status "Porta 80 (HTTP) e 443 (HTTPS) liberadas no firewall" "Falha ao configurar firewall!"

# ============================================================================
# ETAPA 7: INICIALIZAÇÃO E VERIFICAÇÃO DOS SERVIÇOS
# ============================================================================

print_separator "ETAPA 7: INICIANDO E HABILITANDO SERVIÇOS"

print_message "info" "Habilitando Apache para iniciar com o sistema..."
systemctl enable apache2 >> "$LOG_FILE" 2>&1
check_status "Apache configurado para iniciar automaticamente" "Falha ao habilitar Apache!"

print_message "info" "Reiniciando serviço Apache..."
systemctl restart apache2 >> "$LOG_FILE" 2>&1
check_status "Apache reiniciado com sucesso!" "Falha ao reiniciar Apache!"

print_message "info" "Verificando status do Apache..."
sleep 2
if systemctl is-active --quiet apache2; then
    print_message "success" "Apache está em execução!"
else
    print_message "error" "Apache não está em execução!"
    exit 1
fi

# ============================================================================
# ETAPA 8: LIMPEZA DE ARQUIVOS TEMPORÁRIOS
# ============================================================================

print_separator "ETAPA 8: LIMPANDO ARQUIVOS TEMPORÁRIOS"

print_message "info" "Removendo arquivos temporários..."
rm -rf /tmp/template_temp >> "$LOG_FILE" 2>&1
rm -f /tmp/"$TEMPLATE_NAME" >> "$LOG_FILE" 2>&1
check_status "Arquivos temporários removidos!" "Falha ao remover arquivos temporários!"

# ============================================================================
# ETAPA 9: TESTES E VERIFICAÇÕES FINAIS
# ============================================================================

print_separator "ETAPA 9: REALIZANDO TESTES FINAIS"

print_message "info" "Testando conectividade do servidor web..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)

if [ "$HTTP_CODE" = "200" ]; then
    print_message "success" "Servidor respondeu com código HTTP 200 (OK)!"
else
    print_message "warning" "Servidor respondeu com código HTTP $HTTP_CODE"
fi

# Obter endereço IP do servidor
SERVER_IP=$(hostname -I | awk '{print $1}')

print_message "info" "Verificando arquivos instalados..."
if [ -f "$APACHE_DIR/index.html" ]; then
    print_message "success" "Arquivo index.html encontrado!"
else
    print_message "warning" "Arquivo index.html não encontrado!"
fi

# ============================================================================
# RELATÓRIO FINAL
# ============================================================================

print_separator "INSTALAÇÃO CONCLUÍDA COM SUCESSO!"

echo -e "${GREEN}"
cat << "EOF"
    ___                  _          _ 
   / _ \                | |        | |
  / /_\ \_ __   __ _  __| |__   ___| |
  |  _  | '_ \ / _` |/ _| '_ \ / _ \ |
  | | | | |_) | (_| | (_| | | |  __/_|
  \_| |_/ .__/ \__,_|\__|_| |_|\___(_)
        | |                            
        |_|                            
EOF
echo -e "${NC}"

print_message "success" "Servidor Web Apache instalado e configurado!"
echo ""
echo "=============================================================================="
echo "                        INFORMAÇÕES DO SERVIDOR"
echo "=============================================================================="
echo -e "${BLUE}Endereço de Acesso:${NC}      http://$SERVER_IP"
echo -e "${BLUE}Endereço Local:${NC}          http://localhost"
echo -e "${BLUE}Diretório Web:${NC}           $APACHE_DIR"
echo -e "${BLUE}Arquivo de Log:${NC}          $LOG_FILE"
if [ -d "$BACKUP_DIR" ]; then
    echo -e "${BLUE}Backup Anterior:${NC}         $BACKUP_DIR"
fi
echo "=============================================================================="
echo ""
echo -e "${YELLOW}Comandos Úteis:${NC}"
echo "  - Ver status do Apache:       systemctl status apache2"
echo "  - Parar Apache:               systemctl stop apache2"
echo "  - Iniciar Apache:             systemctl start apache2"
echo "  - Reiniciar Apache:           systemctl restart apache2"
echo "  - Ver logs do Apache:         tail -f /var/log/apache2/error.log"
echo "  - Editar página principal:    nano $APACHE_DIR/index.html"
echo ""
echo "=============================================================================="
echo -e "${GREEN}Acesse o navegador e digite o endereço IP acima para ver seu site!${NC}"
echo "=============================================================================="
echo ""

# Perguntar se deseja abrir o navegador (se disponível)
if command -v w3m &> /dev/null; then
    if ask_confirmation "Deseja visualizar o site no terminal agora?"; then
        w3m http://localhost
    fi
fi

print_message "info" "Instalação finalizada em: $(date '+%d/%m/%Y %H:%M:%S')"

exit 0