#!/bin/bash

################################################################################
# Script de Automação - Servidor HTTP (VERSÃO CORRIGIDA)
# Aluno: Samuel Raposo Da Gama
# RM: 561640
# Descrição: Script para automatizar a implementação completa de um servidor HTTP
#            com configurações avançadas de segurança e performance
################################################################################

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para exibir mensagens formatadas
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

log_step() {
    echo -e "${PURPLE}[ETAPA]${NC} $1"
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

# Função para exibir barra de progresso
show_progress() {
    echo -ne "${CYAN}Processando... ${NC}"
    for i in {1..3}; do
        echo -ne "▓"
        sleep 0.3
    done
    echo -e " ${GREEN}✓${NC}"
}

# Início do Script
clear
echo "################################################################################"
echo "#                                                                              #"
echo "#              INSTALAÇÃO E CONFIGURAÇÃO DO SERVIDOR HTTP                     #"
echo "#                      Aluno: Samuel Raposo Da Gama                           #"
echo "#                            RM: 561640                                       #"
echo "#                                                                              #"
echo "################################################################################"
echo ""

# Verificar se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then 
    log_error "Este script precisa ser executado como root (sudo)"
    exit 1
fi

log_info "Iniciando processo de instalação e configuração do servidor HTTP..."
sleep 2

################################################################################
# ETAPA 1: ATUALIZAÇÃO DO SISTEMA
################################################################################
log_step "ETAPA 1: Atualização do Sistema Operacional"
echo "────────────────────────────────────────────────────────────────────────────────"

log_info "Atualizando lista de repositórios..."
apt-get update -y > /dev/null 2>&1
check_status "Repositórios atualizados com sucesso" "Falha ao atualizar repositórios"

log_info "Atualizando pacotes instalados no sistema..."
apt-get upgrade -y > /dev/null 2>&1
check_status "Pacotes atualizados com sucesso" "Falha ao atualizar pacotes"

echo ""

################################################################################
# ETAPA 2: INSTALAÇÃO DO APACHE2
################################################################################
log_step "ETAPA 2: Instalação do Servidor Web Apache2"
echo "────────────────────────────────────────────────────────────────────────────────"

log_info "Instalando Apache2 e dependências..."
apt-get install apache2 apache2-utils -y > /dev/null 2>&1
check_status "Apache2 instalado com sucesso" "Falha ao instalar Apache2"

# Verificar instalação
APACHE_VERSION=$(apache2 -v | head -n 1 | awk '{print $3}')
log_success "Versão instalada: $APACHE_VERSION"

echo ""

################################################################################
# ETAPA 3: CONFIGURAÇÃO DE IP ESTÁTICO/FIXO
################################################################################
log_step "ETAPA 3: Configuração de IP Estático (Fixo)"
echo "────────────────────────────────────────────────────────────────────────────────"

# Detectar interface de rede principal
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
log_info "Interface de rede detectada: $INTERFACE"

# Obter IP atual
CURRENT_IP=$(hostname -I | awk '{print $1}')
log_info "IP atual do sistema: $CURRENT_IP"

# Obter gateway
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
log_info "Gateway detectado: $GATEWAY"

# Definir IP fixo
STATIC_IP="$CURRENT_IP"
NETMASK="255.255.255.0"
NETWORK=$(echo $STATIC_IP | cut -d. -f1-3).0
DNS1="8.8.8.8"
DNS2="8.8.4.4"

log_info "Configurando IP fixo: $STATIC_IP"

# Detectar qual sistema de rede está sendo usado
if [ -d "/etc/netplan" ] && [ "$(ls -A /etc/netplan 2>/dev/null)" ]; then
    # Sistema usa Netplan
    log_info "Sistema usa Netplan - configurando via Netplan..."
    
    # Backup
    cp /etc/netplan/*.yaml /etc/netplan/backup-netplan-$(date +%Y%m%d-%H%M%S).yaml 2>/dev/null || true
    
    # Criar configuração
    cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $STATIC_IP/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses:
          - $DNS1
          - $DNS2
EOF
    
    netplan apply > /dev/null 2>&1
    check_status "IP estático configurado via Netplan: $STATIC_IP" "Falha ao configurar IP via Netplan"

elif systemctl is-active --quiet NetworkManager; then
    # Sistema usa NetworkManager
    log_info "Sistema usa NetworkManager - configurando via nmcli..."
    
    # Obter nome da conexão
    CONNECTION=$(nmcli -t -f NAME,DEVICE connection show | grep "$INTERFACE" | cut -d: -f1 | head -n 1)
    
    if [ -z "$CONNECTION" ]; then
        CONNECTION="$INTERFACE"
    fi
    
    log_info "Configurando conexão: $CONNECTION"
    
    # Configurar IP estático
    nmcli connection modify "$CONNECTION" ipv4.addresses "$STATIC_IP/24" > /dev/null 2>&1
    nmcli connection modify "$CONNECTION" ipv4.gateway "$GATEWAY" > /dev/null 2>&1
    nmcli connection modify "$CONNECTION" ipv4.dns "$DNS1 $DNS2" > /dev/null 2>&1
    nmcli connection modify "$CONNECTION" ipv4.method manual > /dev/null 2>&1
    nmcli connection down "$CONNECTION" > /dev/null 2>&1
    nmcli connection up "$CONNECTION" > /dev/null 2>&1
    
    check_status "IP estático configurado via NetworkManager: $STATIC_IP" "Falha ao configurar IP via NetworkManager"

elif [ -f "/etc/network/interfaces" ]; then
    # Sistema usa arquivo interfaces tradicional
    log_info "Sistema usa /etc/network/interfaces - configurando manualmente..."
    
    # Backup
    cp /etc/network/interfaces /etc/network/interfaces.backup-$(date +%Y%m%d-%H%M%S)
    
    # Verificar se a interface já está configurada
    if grep -q "iface $INTERFACE" /etc/network/interfaces; then
        # Remover configuração antiga da interface
        sed -i "/iface $INTERFACE/,/^$/d" /etc/network/interfaces
    fi
    
    # Adicionar configuração de IP estático
    cat >> /etc/network/interfaces << EOF

# Configuração de IP estático - Samuel Raposo
auto $INTERFACE
iface $INTERFACE inet static
    address $STATIC_IP
    netmask $NETMASK
    network $NETWORK
    gateway $GATEWAY
    dns-nameservers $DNS1 $DNS2
EOF
    
    # Reiniciar interface
    ifdown $INTERFACE > /dev/null 2>&1 || true
    ifup $INTERFACE > /dev/null 2>&1
    
    check_status "IP estático configurado via /etc/network/interfaces: $STATIC_IP" "Falha ao configurar IP"

else
    log_warning "Sistema de rede não identificado - mantendo configuração DHCP atual"
    log_warning "IP atual será mantido mas pode mudar após reinicialização: $CURRENT_IP"
fi

echo ""

################################################################################
# ETAPA 4: CONFIGURAÇÃO DE SEGURANÇA DO APACHE
################################################################################
log_step "ETAPA 4: Configuração de Segurança do Apache"
echo "────────────────────────────────────────────────────────────────────────────────"

log_info "Ocultando versão do Apache no cabeçalho HTTP (ServerTokens)..."

# Backup do arquivo de configuração original
cp /etc/apache2/conf-available/security.conf /etc/apache2/conf-available/security.conf.backup

# Configurar para ocultar informações do servidor
sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf

check_status "Versão do Apache ocultada no cabeçalho HTTP" "Falha ao configurar segurança"

log_info "Verificando configurações de segurança aplicadas..."
grep "ServerTokens" /etc/apache2/conf-available/security.conf | grep -v "^#"
grep "ServerSignature" /etc/apache2/conf-available/security.conf | grep -v "^#"

echo ""

################################################################################
# ETAPA 5: CONFIGURAÇÃO DE INICIALIZAÇÃO AUTOMÁTICA
################################################################################
log_step "ETAPA 5: Configuração de Inicialização Automática"
echo "────────────────────────────────────────────────────────────────────────────────"

log_info "Habilitando Apache2 para iniciar automaticamente com o sistema..."
systemctl enable apache2 > /dev/null 2>&1
check_status "Apache2 configurado para inicialização automática" "Falha ao habilitar inicialização automática"

log_info "Verificando status do serviço..."
systemctl is-enabled apache2 > /dev/null 2>&1
check_status "Serviço configurado corretamente (enabled)" "Serviço não está habilitado"

echo ""

################################################################################
# ETAPA 6: CONFIGURAÇÃO DO FIREWALL
################################################################################
log_step "ETAPA 6: Configuração do Firewall (UFW)"
echo "────────────────────────────────────────────────────────────────────────────────"

log_info "Instalando UFW (Uncomplicated Firewall)..."
apt-get install ufw -y > /dev/null 2>&1
check_status "UFW instalado com sucesso" "Falha ao instalar UFW"

log_info "Configurando regras do firewall..."
# Permitir SSH para não perder acesso
ufw allow 22/tcp > /dev/null 2>&1
# Permitir HTTP e HTTPS
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
# Permitir perfil completo do Apache
ufw allow 'Apache Full' > /dev/null 2>&1

log_info "Ativando firewall..."
echo "y" | ufw enable > /dev/null 2>&1
check_status "Firewall configurado e ativado" "Falha ao configurar firewall"

echo ""

################################################################################
# ETAPA 7: DOWNLOAD E INSTALAÇÃO DO TEMPLATE HTML
################################################################################
log_step "ETAPA 7: Download e Instalação de Template HTML Profissional"
echo "────────────────────────────────────────────────────────────────────────────────"

log_info "Criando template HTML profissional..."

cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Servidor HTTP - Samuel Raposo Da Gama">
    <meta name="author" content="Samuel Raposo Da Gama">
    <title>Servidor HTTP Profissional - Samuel Raposo Da Gama</title>
    
    <style>
        /* Reset CSS */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        /* Variáveis CSS */
        :root {
            --primary-color: #2c3e50;
            --secondary-color: #3498db;
            --accent-color: #e74c3c;
            --success-color: #27ae60;
            --warning-color: #f39c12;
            --light-bg: #ecf0f1;
            --dark-text: #2c3e50;
            --light-text: #ffffff;
            --shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
        }
        
        /* Estilos Globais */
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: var(--dark-text);
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        
        /* Header */
        header {
            background: var(--primary-color);
            color: var(--light-text);
            padding: 1rem 0;
            box-shadow: var(--shadow);
            position: sticky;
            top: 0;
            z-index: 1000;
        }
        
        .header-content {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
        }
        
        .logo {
            font-size: 1.8rem;
            font-weight: bold;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .status-badge {
            background: var(--success-color);
            padding: 0.3rem 1rem;
            border-radius: 20px;
            font-size: 0.9rem;
            animation: pulse 2s infinite;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        /* Container Principal */
        .container {
            max-width: 1200px;
            margin: 2rem auto;
            padding: 0 2rem;
            flex: 1;
        }
        
        /* Card Hero */
        .hero-card {
            background: white;
            border-radius: 20px;
            padding: 3rem;
            box-shadow: var(--shadow);
            margin-bottom: 2rem;
            animation: fadeInUp 0.8s ease-out;
        }
        
        .hero-title {
            font-size: 2.5rem;
            color: var(--primary-color);
            margin-bottom: 1rem;
            text-align: center;
        }
        
        .hero-subtitle {
            font-size: 1.2rem;
            color: #7f8c8d;
            text-align: center;
            margin-bottom: 2rem;
        }
        
        /* Grid de Informações */
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin: 2rem 0;
        }
        
        .info-card {
            background: white;
            border-radius: 15px;
            padding: 2rem;
            box-shadow: var(--shadow);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            animation: fadeInUp 0.8s ease-out;
        }
        
        .info-card:hover {
            transform: translateY(-10px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.2);
        }
        
        .info-card-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        
        .info-card-title {
            font-size: 1.3rem;
            color: var(--primary-color);
            margin-bottom: 0.5rem;
            font-weight: 600;
        }
        
        .info-card-content {
            color: #7f8c8d;
            font-size: 1rem;
        }
        
        /* Seção de Detalhes */
        .details-section {
            background: white;
            border-radius: 20px;
            padding: 2rem;
            box-shadow: var(--shadow);
            margin-bottom: 2rem;
            animation: fadeInUp 1s ease-out;
        }
        
        .details-title {
            font-size: 1.8rem;
            color: var(--primary-color);
            margin-bottom: 1.5rem;
            border-left: 4px solid var(--secondary-color);
            padding-left: 1rem;
        }
        
        .details-list {
            list-style: none;
            padding: 0;
        }
        
        .details-list li {
            padding: 1rem;
            border-bottom: 1px solid #ecf0f1;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .details-list li:last-child {
            border-bottom: none;
        }
        
        .detail-label {
            font-weight: 600;
            color: var(--primary-color);
        }
        
        .detail-value {
            color: #7f8c8d;
        }
        
        /* Estatísticas */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1.5rem;
            margin: 2rem 0;
        }
        
        .stat-card {
            background: linear-gradient(135deg, var(--secondary-color), #2980b9);
            color: white;
            border-radius: 15px;
            padding: 2rem;
            text-align: center;
            box-shadow: var(--shadow);
            transition: transform 0.3s ease;
        }
        
        .stat-card:hover {
            transform: scale(1.05);
        }
        
        .stat-number {
            font-size: 2.5rem;
            font-weight: bold;
            margin-bottom: 0.5rem;
        }
        
        .stat-label {
            font-size: 1rem;
            opacity: 0.9;
        }
        
        /* Footer */
        footer {
            background: var(--primary-color);
            color: var(--light-text);
            text-align: center;
            padding: 2rem;
            margin-top: auto;
        }
        
        .footer-content {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .footer-text {
            margin-bottom: 1rem;
        }
        
        .footer-links {
            display: flex;
            justify-content: center;
            gap: 2rem;
            flex-wrap: wrap;
            margin-top: 1rem;
        }
        
        .footer-link {
            color: var(--light-text);
            text-decoration: none;
            transition: color 0.3s ease;
        }
        
        .footer-link:hover {
            color: var(--secondary-color);
        }
        
        /* Animações */
        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        @keyframes pulse {
            0%, 100% {
                transform: scale(1);
            }
            50% {
                transform: scale(1.05);
            }
        }
        
        @keyframes spin {
            from {
                transform: rotate(0deg);
            }
            to {
                transform: rotate(360deg);
            }
        }
        
        /* Responsividade */
        @media (max-width: 768px) {
            .header-content {
                flex-direction: column;
                gap: 1rem;
            }
            
            .hero-title {
                font-size: 2rem;
            }
            
            .hero-card {
                padding: 2rem 1.5rem;
            }
            
            .info-grid {
                grid-template-columns: 1fr;
            }
            
            .stats-grid {
                grid-template-columns: 1fr;
            }
        }
        
        /* Indicador de carregamento */
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top-color: white;
            animation: spin 1s linear infinite;
        }
    </style>
</head>
<body>
    <!-- Header -->
    <header>
        <div class="header-content">
            <div class="logo">
                🚀 Servidor HTTP Profissional
            </div>
            <div class="status-badge">
                <span class="loading"></span>
                <span>Sistema Online</span>
            </div>
        </div>
    </header>
    
    <!-- Container Principal -->
    <div class="container">
        <!-- Hero Card -->
        <div class="hero-card">
            <h1 class="hero-title">🎯 Servidor Configurado com Sucesso!</h1>
            <p class="hero-subtitle">Sistema implementado e configurado automaticamente via Shell Script</p>
            
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-number">100%</div>
                    <div class="stat-label">Operacional</div>
                </div>
                <div class="stat-card" style="background: linear-gradient(135deg, var(--success-color), #229954);">
                    <div class="stat-number">✓</div>
                    <div class="stat-label">Seguro</div>
                </div>
                <div class="stat-card" style="background: linear-gradient(135deg, var(--warning-color), #d68910);">
                    <div class="stat-number">⚡</div>
                    <div class="stat-label">Alta Performance</div>
                </div>
                <div class="stat-card" style="background: linear-gradient(135deg, var(--accent-color), #c0392b);">
                    <div class="stat-number">🔒</div>
                    <div class="stat-label">IP Configurado</div>
                </div>
            </div>
        </div>
        
        <!-- Grid de Informações -->
        <div class="info-grid">
            <div class="info-card">
                <div class="info-card-icon">👤</div>
                <div class="info-card-title">Aluno</div>
                <div class="info-card-content">Samuel Raposo Da Gama</div>
            </div>
            
            <div class="info-card">
                <div class="info-card-icon">🎓</div>
                <div class="info-card-title">RM</div>
                <div class="info-card-content">561640</div>
            </div>
            
            <div class="info-card">
                <div class="info-card-icon">📚</div>
                <div class="info-card-title">Disciplina</div>
                <div class="info-card-content">Backup e Shell Script</div>
            </div>
            
            <div class="info-card">
                <div class="info-card-icon">📅</div>
                <div class="info-card-title">Data</div>
                <div class="info-card-content"><script>document.write(new Date().toLocaleDateString('pt-BR'));</script></div>
            </div>
        </div>
        
        <!-- Detalhes do Sistema -->
        <div class="details-section">
            <h2 class="details-title">📊 Informações do Sistema</h2>
            <ul class="details-list">
                <li>
                    <span class="detail-label">🖥️ Servidor Web:</span>
                    <span class="detail-value">Apache 2</span>
                </li>
                <li>
                    <span class="detail-label">🔐 Segurança:</span>
                    <span class="detail-value">Firewall UFW Ativo + Versão Oculta</span>
                </li>
                <li>
                    <span class="detail-label">🌐 Rede:</span>
                    <span class="detail-value">IP Configurado</span>
                </li>
                <li>
                    <span class="detail-label">⚙️ Inicialização:</span>
                    <span class="detail-value">Automática com o Sistema</span>
                </li>
                <li>
                    <span class="detail-label">📝 Documentação:</span>
                    <span class="detail-value">Script Completo e Comentado</span>
                </li>
                <li>
                    <span class="detail-label">🎨 Template:</span>
                    <span class="detail-value">HTML5 Responsivo Profissional</span>
                </li>
            </ul>
        </div>
        
        <!-- Recursos Implementados -->
        <div class="details-section">
            <h2 class="details-title">✨ Recursos Implementados</h2>
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-card-icon">🔧</div>
                    <div class="info-card-title">Automatização Total</div>
                    <div class="info-card-content">Instalação e configuração 100% automatizada</div>
                </div>
                
                <div class="info-card">
                    <div class="info-card-icon">🛡️</div>
                    <div class="info-card-title">Segurança Avançada</div>
                    <div class="info-card-content">Firewall e versão oculta</div>
                </div>
                
                <div class="info-card">
                    <div class="info-card-icon">📱</div>
                    <div class="info-card-title">Design Responsivo</div>
                    <div class="info-card-content">Adaptável a todos os dispositivos</div>
                </div>
                
                <div class="info-card">
                    <div class="info-card-icon">⚡</div>
                    <div class="info-card-title">Alta Performance</div>
                    <div class="info-card-content">Otimizado para velocidade</div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Footer -->
    <footer>
        <div class="footer-content">
            <p class="footer-text">
                <strong>Global Solution 2024</strong> - Automação de Infraestrutura com Shell Script
            </p>
            <p class="footer-text">
                Este servidor foi configurado automaticamente através de Shell Script avançado
            </p>
            <div class="footer-links">
                <a href="#" class="footer-link">📖 Documentação</a>
                <a href="#" class="footer-link">🔧 Configurações</a>
                <a href="#" class="footer-link">📊 Monitoramento</a>
                <a href="#" class="footer-link">💬 Suporte</a>
            </div>
            <p style="margin-top: 1rem; opacity: 0.8; font-size: 0.9rem;">
                © 2024 Samuel Raposo Da Gama - Todos os direitos reservados
            </p>
        </div>
    </footer>
    
    <!-- Script para atualizar hora -->
    <script>
        // Atualizar data em tempo real
        function updateDateTime() {
            const now = new Date();
            const dateStr = now.toLocaleDateString('pt-BR', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric'
            });
            const timeStr = now.toLocaleTimeString('pt-BR');
            
            console.log('Sistema Online:', dateStr, timeStr);
        }
        
        setInterval(updateDateTime, 1000);
        
        console.log('%c🚀 Servidor HTTP Inicializado com Sucesso!', 'color: #27ae60; font-size: 20px; font-weight: bold;');
        console.log('%cAluno: Samuel Raposo Da Gama | RM: 561640', 'color: #3498db; font-size: 14px;');
    </script>
</body>
</html>
HTMLEOF

check_status "Template HTML profissional instalado com sucesso" "Falha ao instalar template"

log_success "Página web customizada criada em /var/www/html/index.html"

echo ""

################################################################################
# ETAPA 8: CONFIGURAÇÃO DE PERMISSÕES
################################################################################
log_step "ETAPA 8: Configuração de Permissões e Propriedades"
echo "────────────────────────────────────────────────────────────────────────────────"

log_info "Configurando propriedade dos arquivos web..."
chown -R www-data:www-data /var/www/html/
check_status "Propriedade configurada (www-data)" "Falha ao configurar propriedade"

log_info "Configurando permissões do diretório web..."
chmod -R 755 /var/www/html/
check_status "Permissões configuradas (755)" "Falha ao configurar permissões"

echo ""

################################################################################
# ETAPA 9: INICIALIZAÇÃO E VERIFICAÇÃO DO APACHE
################################################################################
log_step "ETAPA 9: Inicialização e Verificação do Apache"
echo "────────────────────────────────────────────────────────────────────────────────"

log_info "Reiniciando Apache para aplicar todas as configurações..."
systemctl restart apache2 > /dev/null 2>&1
check_status "Apache reiniciado com sucesso" "Falha ao reiniciar Apache"

log_info "Verificando status do serviço Apache..."
systemctl is-active --quiet apache2
check_status "Apache está rodando corretamente" "Apache não está rodando"

log_info "Testando configuração do Apache..."
apache2ctl configtest > /dev/null 2>&1
check_status "Configuração do Apache válida" "Configuração do Apache inválida"

echo ""

################################################################################
# ETAPA 10: GERAÇÃO DE RELATÓRIO E LOG
################################################################################
log_step "ETAPA 10: Geração de Relatório e Arquivo de Log"
echo "────────────────────────────────────────────────────────────────────────────────"

log_info "Coletando informações do sistema..."

# Coletar informações
IP_ADDRESS=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
OS_VERSION=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux")
KERNEL_VERSION=$(uname -r)
APACHE_VERSION=$(apache2 -v | head -n 1 | awk '{print $3}')
TOTAL_MEMORY=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "N/A")
DISK_USAGE=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' || echo "N/A")
UPTIME=$(uptime -p 2>/dev/null || echo "N/A")

show_progress

log_info "Criando arquivo de log detalhado..."

# Criar log completo
LOG_FILE="/var/log/instalacao_http_samuel_$(date +%Y%m%d_%H%M%S).log"

cat > $LOG_FILE << LOGEOF
================================================================================
        RELATÓRIO COMPLETO DE INSTALAÇÃO - SERVIDOR HTTP
================================================================================

INFORMAÇÕES DO PROJETO
----------------------
Aluno               : Samuel Raposo Da Gama
RM                  : 561640
Disciplina          : Backup e Shell Script
Tipo de Projeto     : Global Solution - Automação de Servidor HTTP
Data de Instalação  : $(date '+%d/%m/%Y às %H:%M:%S')

INFORMAÇÕES DO SISTEMA
----------------------
Hostname            : $HOSTNAME
Sistema Operacional : $OS_VERSION
Versão do Kernel    : $KERNEL_VERSION
Endereço IP         : $IP_ADDRESS
Memória Total       : $TOTAL_MEMORY
Uso de Disco (/)    : $DISK_USAGE
Tempo de Atividade  : $UPTIME

COMPONENTES INSTALADOS
----------------------
✓ Apache2           : $APACHE_VERSION
✓ UFW Firewall      : Ativo e Configurado
✓ IP                : Configurado
✓ Template HTML     : HTML5 Responsivo Instalado

CONFIGURAÇÕES DE SEGURANÇA
--------------------------
✓ ServerTokens      : Prod (Versão oculta no cabeçalho)
✓ ServerSignature   : Off
✓ Firewall UFW      : Ativo
  - Porta 22/tcp    : Permitida (SSH)
  - Porta 80/tcp    : Permitida (HTTP)
  - Porta 443/tcp   : Permitida (HTTPS)
  - Apache Full     : Permitido

CONFIGURAÇÕES DE REDE
---------------------
Interface           : $INTERFACE
IP Atual            : $IP_ADDRESS
Gateway             : $GATEWAY
DNS Primário        : $DNS1
DNS Secundário      : $DNS2

SERVIÇOS E INICIALIZAÇÃO
------------------------
Status do Apache    : $(systemctl is-active apache2)
Inicialização Auto  : $(systemctl is-enabled apache2)
Teste de Config     : $(apache2ctl configtest 2>&1 | grep -o "Syntax OK")

ARQUIVOS E DIRETÓRIOS
---------------------
DocumentRoot        : /var/www/html
Página Principal    : /var/www/html/index.html
Config. Apache      : /etc/apache2/
Config. Segurança   : /etc/apache2/conf-available/security.conf
Logs do Apache      : /var/log/apache2/

RESUMO DA INSTALAÇÃO
--------------------
✓ Sistema atualizado
✓ Apache2 instalado e configurado
✓ IP configurado
✓ Versão do Apache ocultada (ServerTokens Prod)
✓ Inicialização automática habilitada
✓ Firewall configurado e ativo
✓ Template HTML profissional instalado
✓ Permissões configuradas corretamente
✓ Testes de configuração: OK

PRÓXIMOS PASSOS
---------------
1. Acesse o servidor via navegador: http://$IP_ADDRESS
2. Verifique o funcionamento da página web
3. Monitore os logs em: /var/log/apache2/
4. Crie backup da configuração
5. Clone a VM para produção conforme orientação

================================================================================
                    INSTALAÇÃO CONCLUÍDA COM SUCESSO!
================================================================================
Script executado por: $(whoami)
Log gerado em: $LOG_FILE
================================================================================
LOGEOF

check_status "Arquivo de log criado: $LOG_FILE" "Falha ao criar log"

echo ""

################################################################################
# ETAPA 11: EXIBIÇÃO DO RESUMO FINAL
################################################################################
log_step "ETAPA 11: Resumo Final da Instalação"
echo "────────────────────────────────────────────────────────────────────────────────"

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                            ║"
echo "║                  ✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO! ✓                    ║"
echo "║                                                                            ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

log_success "Todas as etapas foram concluídas com sucesso!"
echo ""

echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN}                    INFORMAÇÕES DO SERVIDOR                               ${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  ${BLUE}🌐 URL de Acesso:${NC}         http://$IP_ADDRESS"
echo "  ${BLUE}📍 Endereço IP:${NC}           $IP_ADDRESS"
echo "  ${BLUE}🖥️  Hostname:${NC}             $HOSTNAME"
echo "  ${BLUE}🔧 Versão Apache:${NC}         $APACHE_VERSION"
echo "  ${BLUE}💾 Sistema Operacional:${NC}   $OS_VERSION"
echo "  ${BLUE}📝 Log de Instalação:${NC}     $LOG_FILE"
echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN}                 CONFIGURAÇÕES APLICADAS                                 ${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  ${GREEN}✓${NC} Sistema atualizado"
echo "  ${GREEN}✓${NC} Apache2 instalado e configurado"
echo "  ${GREEN}✓${NC} IP configurado"
echo "  ${GREEN}✓${NC} Versão do Apache ocultada (ServerTokens Prod)"
echo "  ${GREEN}✓${NC} Inicialização automática habilitada"
echo "  ${GREEN}✓${NC} Firewall UFW ativo e configurado"
echo "  ${GREEN}✓${NC} Template HTML profissional instalado"
echo "  ${GREEN}✓${NC} Permissões e propriedades configuradas"
echo "  ${GREEN}✓${NC} Arquivo de log detalhado gerado"
echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
log_warning "IMPORTANTE: Lembre-se dos próximos passos obrigatórios:"
echo ""
echo "  ${YELLOW}1.${NC} Testar o servidor acessando: ${CYAN}http://$IP_ADDRESS${NC}"
echo "  ${YELLOW}2.${NC} Verificar o funcionamento de todas as configurações"
echo "  ${YELLOW}3.${NC} Criar clone da VM:"
echo "     ${BLUE}→${NC} VM Atual: ${GREEN}Samuel Raposo Da Gama - Homologação${NC}"
echo "     ${BLUE}→${NC} Novo Clone: ${GREEN}Samuel Raposo Da Gama - Produção${NC}"
echo "  ${YELLOW}4.${NC} Apresentar o clone de Produção ao professor"
echo ""

log_info "O sistema será reiniciado em 10 segundos para aplicar todas as configurações..."
echo ""

# Contador regressivo
for i in {10..1}; do
    echo -ne "${YELLOW}Reiniciando em $i segundos...${NC}\r"
    sleep 1
done

echo ""
echo ""
log_success "Preparando para reiniciar o sistema..."
echo ""

################################################################################
# ETAPA 12: REINICIALIZAÇÃO DO SISTEMA
################################################################################
log_step "ETAPA 12: Reinicialização do Sistema"
echo "────────────────────────────────────────────────────────────────────────────────"

log_warning "Reiniciando o sistema para aplicar todas as configurações..."
sleep 2

# Reiniciar o sistema
reboot

################################################################################
# FIM DO SCRIPT
################################################################################
