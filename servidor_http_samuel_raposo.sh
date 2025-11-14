#!/bin/bash

################################################################################
# Script de Automação - Servidor HTTP
# Aluno: Samuel Raposo Da Gama
# RM: 561640
# Descrição: Script para automatizar a implementação de um servidor HTTP
################################################################################

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Função para verificar se o comando foi executado com sucesso
check_status() {
    if [ $? -eq 0 ]; then
        log_success "$1"
    else
        log_error "$2"
        exit 1
    fi
}

# Início do Script
clear
echo "################################################################################"
echo "#                    INSTALAÇÃO DO SERVIDOR HTTP                              #"
echo "#                   Aluno: Samuel Raposo Da Gama                              #"
echo "#                          RM: 561640                                         #"
echo "################################################################################"
echo ""

# Verificar se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then 
    log_error "Este script precisa ser executado como root (sudo)"
    exit 1
fi

log_info "Iniciando processo de instalação do servidor HTTP..."
sleep 2

# 1. Atualizar repositórios do sistema
log_info "Atualizando repositórios do sistema..."
apt-get update -y > /dev/null 2>&1
check_status "Repositórios atualizados com sucesso" "Falha ao atualizar repositórios"

# 2. Atualizar pacotes do sistema
log_info "Atualizando pacotes do sistema..."
apt-get upgrade -y > /dev/null 2>&1
check_status "Pacotes atualizados com sucesso" "Falha ao atualizar pacotes"

# 3. Instalar Apache2
log_info "Instalando servidor Apache2..."
apt-get install apache2 -y > /dev/null 2>&1
check_status "Apache2 instalado com sucesso" "Falha ao instalar Apache2"

# 4. Habilitar o Apache para iniciar no boot
log_info "Habilitando Apache2 para iniciar no boot..."
systemctl enable apache2 > /dev/null 2>&1
check_status "Apache2 habilitado para iniciar no boot" "Falha ao habilitar Apache2"

# 5. Iniciar o serviço Apache
log_info "Iniciando serviço Apache2..."
systemctl start apache2 > /dev/null 2>&1
check_status "Serviço Apache2 iniciado" "Falha ao iniciar Apache2"

# 6. Verificar status do Apache
log_info "Verificando status do serviço Apache2..."
systemctl is-active --quiet apache2
check_status "Apache2 está rodando corretamente" "Apache2 não está rodando"

# 7. Configurar Firewall (UFW)
log_info "Configurando firewall UFW..."
apt-get install ufw -y > /dev/null 2>&1

# Permitir Apache no firewall
ufw allow 'Apache Full' > /dev/null 2>&1
check_status "Firewall configurado para Apache" "Falha ao configurar firewall"

# 8. Criar página HTML personalizada
log_info "Criando página HTML personalizada..."
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Servidor HTTP - Samuel Raposo Da Gama</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 50px;
            max-width: 800px;
            text-align: center;
            animation: fadeIn 1s ease-in;
        }
        
        @keyframes fadeIn {
            from {
                opacity: 0;
                transform: translateY(-30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        h1 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 2.5em;
        }
        
        .info-box {
            background: #f8f9fa;
            border-left: 5px solid #667eea;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
            border-radius: 5px;
        }
        
        .info-box p {
            margin: 10px 0;
            color: #333;
            line-height: 1.6;
        }
        
        .info-box strong {
            color: #667eea;
        }
        
        .status {
            display: inline-block;
            background: #28a745;
            color: white;
            padding: 10px 30px;
            border-radius: 25px;
            margin: 20px 0;
            font-weight: bold;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% {
                transform: scale(1);
            }
            50% {
                transform: scale(1.05);
            }
        }
        
        .footer {
            margin-top: 30px;
            color: #666;
            font-size: 0.9em;
        }
        
        .server-info {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        
        .server-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            transition: transform 0.3s;
        }
        
        .server-card:hover {
            transform: translateY(-5px);
        }
        
        .server-card h3 {
            margin-bottom: 10px;
            font-size: 1.2em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Servidor HTTP Configurado!</h1>
        
        <div class="status">
            ✓ Sistema Online
        </div>
        
        <div class="info-box">
            <p><strong>Aluno:</strong> Samuel Raposo Da Gama</p>
            <p><strong>RM:</strong> 561640</p>
            <p><strong>Projeto:</strong> Automação de Servidor HTTP com Shell Script</p>
            <p><strong>Data de Instalação:</strong> <script>document.write(new Date().toLocaleDateString('pt-BR'));</script></p>
        </div>
        
        <div class="server-info">
            <div class="server-card">
                <h3>🖥️ Servidor Web</h3>
                <p>Apache 2</p>
            </div>
            <div class="server-card">
                <h3>🔒 Segurança</h3>
                <p>Firewall UFW Ativo</p>
            </div>
            <div class="server-card">
                <h3>⚡ Status</h3>
                <p>100% Operacional</p>
            </div>
        </div>
        
        <div class="footer">
            <p>Este servidor foi configurado automaticamente através de Shell Script</p>
            <p>Global Solution - Backup e Shell Script</p>
        </div>
    </div>
</body>
</html>
EOF

check_status "Página HTML personalizada criada" "Falha ao criar página HTML"

# 9. Configurar permissões corretas
log_info "Configurando permissões do diretório web..."
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/
check_status "Permissões configuradas corretamente" "Falha ao configurar permissões"

# 10. Reiniciar Apache para aplicar todas as configurações
log_info "Reiniciando Apache2 para aplicar configurações..."
systemctl restart apache2 > /dev/null 2>&1
check_status "Apache2 reiniciado com sucesso" "Falha ao reiniciar Apache2"

# 11. Coletar informações do sistema
log_info "Coletando informações do sistema..."
IP_ADDRESS=$(hostname -I | awk '{print $1}')
APACHE_VERSION=$(apache2 -v | head -n 1 | awk '{print $3}')
OS_VERSION=$(lsb_release -d | cut -f2)

# 12. Criar arquivo de log com informações da instalação
LOG_FILE="/var/log/instalacao_http_samuel.log"
cat > $LOG_FILE << EOF
================================================================================
RELATÓRIO DE INSTALAÇÃO - SERVIDOR HTTP
================================================================================
Aluno: Samuel Raposo Da Gama
RM: 561640
Data: $(date '+%d/%m/%Y %H:%M:%S')
================================================================================

INFORMAÇÕES DO SISTEMA:
- Sistema Operacional: $OS_VERSION
- Endereço IP: $IP_ADDRESS
- Versão do Apache: $APACHE_VERSION

SERVIÇOS INSTALADOS:
- Apache2: Instalado e Ativo
- UFW Firewall: Configurado

STATUS DOS SERVIÇOS:
$(systemctl status apache2 | grep Active)

PORTAS ABERTAS:
$(netstat -tlnp | grep apache2)

CONFIGURAÇÕES:
- DocumentRoot: /var/www/html
- Página Principal: index.html (personalizada)
- Firewall: Apache Full permitido

================================================================================
INSTALAÇÃO CONCLUÍDA COM SUCESSO!
================================================================================
EOF

log_success "Arquivo de log criado em: $LOG_FILE"

# Exibir resumo final
echo ""
echo "################################################################################"
echo "#                        INSTALAÇÃO CONCLUÍDA!                                #"
echo "################################################################################"
echo ""
log_success "Servidor HTTP instalado e configurado com sucesso!"
echo ""
echo "INFORMAÇÕES DO SERVIDOR:"
echo "  📍 Endereço IP: $IP_ADDRESS"
echo "  🌐 URL de Acesso: http://$IP_ADDRESS"
echo "  🔧 Versão do Apache: $APACHE_VERSION"
echo "  📝 Log de Instalação: $LOG_FILE"
echo ""
log_info "Acesse o servidor através do navegador usando o endereço IP acima"
echo ""
log_warning "Lembre-se de criar os clones da VM conforme solicitado:"
log_warning "  1. VM de Homologação: Samuel Raposo Da Gama - Homologação"
log_warning "  2. VM de Produção: Samuel Raposo Da Gama - Produção"
echo ""
echo "################################################################################"

# Fim do Script
exit 0
