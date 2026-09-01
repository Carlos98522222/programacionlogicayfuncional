#!/bin/bash
# =====================================================================
# Programa:    lanzar-nodo-arm64.sh
# Autor:       MC. René Solis R. — Docente, TecNM Campus Tijuana
# Curso:       Programación Lógica y Funcional (ISC-2006) — Ago–Dic 2026
# Actividad:   Instalación — nodo AWS Academy
# Fecha:       2026-07-18  (rev. 2026-09-01: disco root 30 GB gp3 + swap 4 GB vía
#              user-data; tag Name en instancia y volumen; comandos de gestión)
# Descripción: Lanza la instancia EC2 ARM64 (key pair, security group, AMI Ubuntu 24.04) desde CloudShell
# IA:          Generado con Claude Code, verificado y modificado por el docente
# Ajustes:     INSTANCE_TYPE / ROOT_GB / SWAP_GB son overrideables por variable de entorno
#              ej: INSTANCE_TYPE=t4g.small ROOT_GB=40 ./lanzar-nodo-arm64.sh
# =====================================================================
# ==========================================
# Script: lanzar-nodo-arm64.sh
# Autor: MC. René Solis R. @IoTeacher
# Descripción: Automatizar procedimiento recurrente de nodo ARM64 para curso
#              puede usarse como templete universal
# Origen: https://gist.github.com/IoTeacher/c214a55f457d47ba715362f00434b97e
# Adaptación PLF: nombre/descripción del curso y AMI Ubuntu 24.04 (noble)
# Uso: ejecutar dentro de AWS CloudShell (AWS Academy Learner Lab)
# ==========================================

clear

cat << "EOF"
  ░██████  ░██                              ░██   ░██████   ░██                   ░██ ░██
 ░██   ░██ ░██                              ░██  ░██   ░██  ░██                   ░██ ░██
░██        ░██  ░███████  ░██    ░██  ░████████ ░██         ░████████   ░███████  ░██ ░██
░██        ░██ ░██    ░██ ░██    ░██ ░██    ░██  ░████████  ░██    ░██ ░██    ░██ ░██ ░██
░██        ░██ ░██    ░██ ░██    ░██ ░██    ░██         ░██ ░██    ░██ ░█████████ ░██ ░██
 ░██   ░██ ░██ ░██    ░██ ░██   ░███ ░██   ░███  ░██   ░██  ░██    ░██ ░██        ░██ ░██
  ░██████  ░██  ░███████   ░█████░██  ░█████░██   ░██████   ░██    ░██  ░███████  ░██ ░██
EOF

echo "🧩 CloudShell AWS - Nodo ARM64"

echo "===== CONFIG ====="
export AWS_DEFAULT_REGION=us-east-1
KEY_NAME="llavesita"
SG_NAME="arm64-ssh-group"
DESC="Programacion Logica y Funcional - ARM64"

# Arquitectura: ARM64 (Graviton). Los 6 lenguajes del curso tienen soporte
# aarch64 completo en Ubuntu 24.04 y t4g cuesta ~20% menos que t3.
#   t4g.micro  = 1 GiB  -> Prolog/Erlang/Elixir/OCaml OK; Haskell/Clojure solo REPL
#   t4g.small  = 2 GiB  -> recomendado si el nodo lo comparten varios o se compila Haskell
INSTANCE_TYPE="${INSTANCE_TYPE:-t4g.micro}"

# Etiqueta (tag "Name") con la que se ve la VM en la consola EC2. SIN espacios:
# así el valor no queda con comillas raras y es fácil de filtrar por CLI.
# EC2 no pone nombre por defecto -> sin este tag la instancia sale en blanco y
# solo se distingue por su ID aleatorio (i-0abc...). Overrideable por entorno.
INSTANCE_NAME="${INSTANCE_NAME:-Curso-PLF}"

# Tags que se aplican TANTO a la instancia como a su disco (volumen EBS),
# para que ninguno de los dos aparezca sin nombre en la consola.
TAGS="{Key=Name,Value=$INSTANCE_NAME},{Key=Curso,Value=ISC-2006-PLF},{Key=Proyecto,Value=programacion-logica-y-funcional}"

# Disco root y swap (ghcup ~5GB + opam ~2GB + JVM/BEAM no caben en los 8 GB por defecto)
ROOT_GB="${ROOT_GB:-30}"
SWAP_GB="${SWAP_GB:-4}"

echo "===== 1. Key Pair ====="

# Verificar si existe la key en AWS
aws ec2 describe-key-pairs --key-names $KEY_NAME > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "⚠️ Key existe en AWS"

  # Verificar si existe el archivo local
  if [ ! -f "${KEY_NAME}.pem" ]; then
    echo "❌ No existe ${KEY_NAME}.pem local → recreando key..."

    aws ec2 delete-key-pair --key-name $KEY_NAME

    aws ec2 create-key-pair \
      --key-name $KEY_NAME \
      --query 'KeyMaterial' \
      --output text > ${KEY_NAME}.pem

    chmod 400 ${KEY_NAME}.pem
  else
    echo "✅ Key y archivo .pem ya existen"
  fi

else
  echo "🆕 Creando nueva key..."

  aws ec2 create-key-pair \
    --key-name $KEY_NAME \
    --query 'KeyMaterial' \
    --output text > ${KEY_NAME}.pem

  chmod 400 ${KEY_NAME}.pem
fi

echo "===== 2. VPC default ====="
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text)

echo "===== 3. Security Group ====="
SG_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=$SG_NAME \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [ "$SG_ID" == "None" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --group-name $SG_NAME \
    --description "$DESC" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
fi

echo "SG_ID: $SG_ID"

echo "===== 4. Abrir puerto 22 ====="
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 2>/dev/null

echo "===== 5. Subnet ====="
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=default-for-az,Values=true" \
  --query "Subnets[0].SubnetId" \
  --output text)

echo "===== 6. AMI Ubuntu ARM64 ====="
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*" \
  --query "Images | sort_by(@, &CreationDate)[-1].ImageId" \
  --output text)

echo "AMI: $AMI_ID"

# Nombre del dispositivo root real de la AMI (Ubuntu suele ser /dev/sda1)
ROOT_DEV=$(aws ec2 describe-images \
  --image-ids $AMI_ID \
  --query "Images[0].RootDeviceName" \
  --output text)

echo "===== 7. user-data (swap + tuning) ====="
cat > user-data.sh << EOF
#!/bin/bash
set -e
# --- swap de ${SWAP_GB} GiB: evita OOM al compilar GHC/opam o al correr la JVM ---
if [ ! -f /swapfile ]; then
  fallocate -l ${SWAP_GB}G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=\$((${SWAP_GB}*1024))
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
# menos agresivo al swapear: usar RAM mientras haya
sysctl -w vm.swappiness=10
echo 'vm.swappiness=10' > /etc/sysctl.d/99-plf-swap.conf
apt-get update -y
EOF

echo "===== 8. Lanzar instancia ====="
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --associate-public-ip-address \
  --block-device-mappings "[{\"DeviceName\":\"$ROOT_DEV\",\"Ebs\":{\"VolumeSize\":$ROOT_GB,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
  --user-data file://user-data.sh \
  --tag-specifications \
      "ResourceType=instance,Tags=[$TAGS]" \
      "ResourceType=volume,Tags=[$TAGS]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instancia: $INSTANCE_ID  Name=$INSTANCE_NAME  ($INSTANCE_TYPE, root ${ROOT_GB}GB gp3, swap ${SWAP_GB}GB)"

echo "===== 9. Esperando ====="
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

echo "===== 10. IP pública ====="
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "IP: $PUBLIC_IP"

echo "===== SSH ====="
echo "ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP"
echo
echo "El user-data crea el swap en el primer arranque (~1 min). Verifica con:"
echo "  ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP 'free -h && df -h /'"
echo
echo "Gestión de esta VM (por su etiqueta Name=$INSTANCE_NAME):"
echo "  Ver estado : aws ec2 describe-instances --filters Name=tag:Name,Values=$INSTANCE_NAME --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' --output table"
echo "  Apagar     : aws ec2 stop-instances  --instance-ids $INSTANCE_ID"
echo "  Encender   : aws ec2 start-instances --instance-ids $INSTANCE_ID"
echo "  Borrar     : aws ec2 terminate-instances --instance-ids $INSTANCE_ID"
