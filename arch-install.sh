#!/bin/bash

# Arch Linux Automated Installation Script
# Запускать из live USB Arch Linux

set -e  # Остановка при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Логирование
LOG_FILE="/tmp/arch-install.log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

# Функции
print_error() {
    echo -e "${RED}[ОШИБКА]${NC} $1"
    exit 1
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $1"
}

print_info() {
    echo -e "[INFO] $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Скрипт должен быть запущен от root"
    fi
    print_success "Проверка root пользователя"
}

check_uefi() {
    if [[ ! -d /sys/firmware/efi ]]; then
        print_error "Система не в режиме UEFI"
    fi
    print_success "Проверка UEFI режима"
}

check_internet() {
    if ! ping -c 1 archlinux.org &> /dev/null; then
        print_error "Нет подключения к интернету"
    fi
    print_success "Проверка интернет-соединения"
}

# Конфигурация (измени под себя)
configure() {
    echo ""
    echo "=========================================="
    echo "    Конфигурация установки Arch Linux"
    echo "=========================================="
    echo ""
    
    # Показать доступные диски
    echo "Доступные диски:"
    lsblk -d -o NAME,SIZE,MODEL
    echo ""
    
    read -p "Введи диск для установки (например, sda или nvme0n1): " DISK
    DISK="/dev/${DISK}"
    
    if [[ ! -b "$DISK" ]]; then
        print_error "Диск $DISK не найден"
    fi
    
    read -p "Размер swap в ГБ (например, 8 или 16): " SWAP_SIZE
    read -p "Имя компьютера: " HOSTNAME
    read -p "Имя пользователя: " USERNAME
    read -p "Часовой пояс (например, Europe/Moscow): " TIMEZONE
    
    echo ""
    echo "=========================================="
    echo "    Установка паролей"
    echo "=========================================="
    echo ""
    
    # Пароль root
    while true; do
        read -s -p "Введи пароль для root: " ROOT_PASSWORD
        echo ""
        read -s -p "Повтори пароль для root: " ROOT_PASSWORD_CONFIRM
        echo ""
        
        if [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]]; then
            if [[ -z "$ROOT_PASSWORD" ]]; then
                print_warning "Пароль не может быть пустым"
            else
                break
            fi
        else
            print_warning "Пароли не совпадают, попробуй снова"
        fi
    done
    print_success "Пароль root принят"
    
    # Пароль пользователя
    while true; do
        read -s -p "Введи пароль для ${USERNAME}: " USER_PASSWORD
        echo ""
        read -s -p "Повтори пароль для ${USERNAME}: " USER_PASSWORD_CONFIRM
        echo ""
        
        if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]]; then
            if [[ -z "$USER_PASSWORD" ]]; then
                print_warning "Пароль не может быть пустым"
            else
                break
            fi
        else
            print_warning "Пароли не совпадают, попробуй снова"
        fi
    done
    print_success "Пароль пользователя принят"
    
    echo ""
    echo "=========================================="
    echo "    Проверь конфигурацию:"
    echo "=========================================="
    echo "Диск: $DISK"
    echo "Swap: ${SWAP_SIZE}G"
    echo "Hostname: $HOSTNAME"
    echo "Username: $USERNAME"
    echo "Timezone: $TIMEZONE"
    echo "Пароли: установлены"
    echo "=========================================="
    echo ""
    
    read -p "Всё верно? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
        print_error "Установка отменена"
    fi
    
    # Определяем имена разделов
    if [[ "$DISK" == *"nvme"* ]]; then
        PART1="${DISK}p1"
        PART2="${DISK}p2"
        PART3="${DISK}p3"
    else
        PART1="${DISK}1"
        PART2="${DISK}2"
        PART3="${DISK}3"
    fi
}

# Разметка диска
partition_disk() {
    print_info "Разметка диска $DISK..."
    
    # Отмонтировать если смонтировано
    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    
    # Создаем новую таблицу разделов
    parted -s "$DISK" mklabel gpt || print_error "Не удалось создать GPT таблицу"
    
    # EFI раздел (512MB)
    parted -s "$DISK" mkpart "EFI" fat32 1MiB 513MiB || print_error "Не удалось создать EFI раздел"
    parted -s "$DISK" set 1 esp on || print_error "Не удалось установить флаг ESP"
    
    # Swap раздел
    parted -s "$DISK" mkpart "swap" linux-swap 513MiB "$((513 + SWAP_SIZE * 1024))MiB" || print_error "Не удалось создать swap раздел"
    
    # Root раздел (остальное место)
    parted -s "$DISK" mkpart "root" ext4 "$((513 + SWAP_SIZE * 1024))MiB" 100% || print_error "Не удалось создать root раздел"
    
    # Ждем пока система увидит разделы
    sleep 2
    partprobe "$DISK"
    sleep 2
    
    print_success "Разметка диска завершена"
}

# Форматирование разделов
format_partitions() {
    print_info "Форматирование разделов..."
    
    mkfs.fat -F32 "$PART1" || print_error "Не удалось форматировать EFI раздел"
    print_success "EFI раздел отформатирован"
    
    mkswap "$PART2" || print_error "Не удалось создать swap"
    swapon "$PART2" || print_error "Не удалось активировать swap"
    print_success "Swap раздел создан и активирован"
    
    mkfs.ext4 -F "$PART3" || print_error "Не удалось форматировать root раздел"
    print_success "Root раздел отформатирован"
}

# Монтирование
mount_partitions() {
    print_info "Монтирование разделов..."
    
    mount "$PART3" /mnt || print_error "Не удалось смонтировать root"
    mkdir -p /mnt/boot
    mount "$PART1" /mnt/boot || print_error "Не удалось смонтировать boot"
    
    print_success "Разделы смонтированы"
}

# Установка базовой системы
install_base() {
    print_info "Установка базовой системы (это займет время)..."
    
    pacstrap -K /mnt base linux linux-firmware || print_error "Не удалось установить базовую систему"
    
    print_success "Базовая система установлена"
}

# Генерация fstab
generate_fstab() {
    print_info "Генерация fstab..."
    
    genfstab -U /mnt >> /mnt/etc/fstab || print_error "Не удалось сгенерировать fstab"
    
    print_success "fstab сгенерирован"
}

# Создание скрипта для chroot
create_chroot_script() {
    print_info "Создание скрипта настройки системы..."
    
    cat > /mnt/setup.sh << CHROOT_SCRIPT
#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_error() { echo -e "\${RED}[ОШИБКА]\${NC} \$1"; exit 1; }
print_success() { echo -e "\${GREEN}[OK]\${NC} \$1"; }

# Часовой пояс
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime || print_error "Timezone"
hwclock --systohc
print_success "Часовой пояс настроен"

# Локализация
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen || print_error "Locale generation"
echo "LANG=en_US.UTF-8" > /etc/locale.conf
print_success "Локализация настроена"

# Hostname
echo "${HOSTNAME}" > /etc/hostname
print_success "Hostname установлен"

# Установка пакетов
pacman -S --noconfirm \
    plasma-desktop sddm networkmanager konsole dolphin \
    sudo nano openssh grub efibootmgr \
    pipewire pipewire-pulse pipewire-alsa wireplumber plasma-pa \
    networkmanager-qt plasma-nm \
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation ttf-dejavu \
    git base-devel zsh \
    || print_error "Установка пакетов"
print_success "Пакеты установлены"

# Включение сервисов
systemctl enable sddm || print_error "Enable sddm"
systemctl enable NetworkManager || print_error "Enable NetworkManager"
print_success "Сервисы включены"

# Создание пользователя
useradd -m -G wheel -s /bin/zsh ${USERNAME} || print_error "Создание пользователя"
print_success "Пользователь ${USERNAME} создан"

# Настройка sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
print_success "Sudo настроен"

# Установка GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || print_error "GRUB install"

# Настройка GRUB (скрыть меню)
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg || print_error "GRUB config"
print_success "GRUB установлен и настроен"

# Настройка сессии KDE (не восстанавливать)
mkdir -p /home/${USERNAME}/.config
echo "[General]
loginMode=emptySession" > /home/${USERNAME}/.config/ksmserverrc
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config
print_success "KDE настроен"

# Установка паролей
echo "root:${ROOT_PASSWORD}" | chpasswd || print_error "Root password"
print_success "Пароль root установлен"

echo "${USERNAME}:${USER_PASSWORD}" | chpasswd || print_error "User password"
print_success "Пароль пользователя установлен"

echo ""
echo -e "\${GREEN}=========================================="
echo "    Установка завершена успешно!"
echo "==========================================${NC}"
echo ""
CHROOT_SCRIPT

    chmod +x /mnt/setup.sh
    print_success "Скрипт настройки создан"
}

# Запуск настройки в chroot
run_chroot() {
    print_info "Запуск настройки системы в chroot..."
    
    arch-chroot /mnt /setup.sh || print_error "Ошибка в chroot"
    
    # Удаляем скрипт
    rm /mnt/setup.sh
    
    print_success "Настройка в chroot завершена"
}

# Завершение
finish() {
    print_info "Завершение установки..."
    
    umount -R /mnt || print_warning "Не удалось отмонтировать разделы"
    
    echo ""
    echo -e "${GREEN}=========================================="
    echo "    Установка Arch Linux завершена!"
    echo "==========================================${NC}"
    echo ""
    echo "Лог установки сохранен в: $LOG_FILE"
    echo ""
    echo "Теперь можно перезагрузиться:"
    echo "  reboot"
    echo ""
    echo "После перезагрузки:"
    echo "  1. Войди под пользователем ${USERNAME}"
    echo "  2. Установи yay для AUR:"
    echo "     git clone https://aur.archlinux.org/yay.git"
    echo "     cd yay && makepkg -si"
    echo ""
}

# Главная функция
main() {
    clear
    echo "=========================================="
    echo "    Arch Linux Automated Installer"
    echo "=========================================="
    echo ""
    
    check_root
    check_uefi
    check_internet
    configure
    partition_disk
    format_partitions
    mount_partitions
    install_base
    generate_fstab
    create_chroot_script
    run_chroot
    finish
}

# Запуск
main
