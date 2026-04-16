#!/bin/bash

# --- Определение директории, где находится скрипт ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ARCHIVE_NAME="hyprland_dotfiles.tar.gz"
TEMP_DIR="dotfiles_import"

echo "🚀 Начинаем установку Hyprland dotfiles..."

# --- 1. Установка пакетов ---
echo "📦 Проверка и установка зависимостей..."
sleep 1

# --- Определение дистрибутива ---
distro="unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro_id="$ID"
    distro_like="$ID_LIKE"
else
    echo "❌ Не удалось определить дистрибутив. Пропускаем установку пакетов."
    distro="unknown"
fi

# Нормализуем имя дистрибутива
if [[ "$distro_id" =~ ^(arch|archarm|manjaro|endeavouros)$ ]] || [[ "$distro_like" =~ (arch) ]]; then
    distro="arch"
elif [[ "$distro_id" =~ ^(debian|ubuntu|linuxmint|pop)$ ]] || [[ "$distro_like" =~ (debian) ]]; then
    distro="debian"
elif [[ "$distro_id" =~ ^(fedora|rhel|centos)$ ]] || [[ "$distro_like" =~ (fedora) ]]; then
    distro="fedora"
fi

echo "🔍 Обнаружен дистрибутив: $distro"

# --- Списки пакетов ---
# Hyprland, Waybar, Mako и другие утилиты
packages_hyprland=(
    "hyprland"          # Композитор
    "hyprpaper"         # Установка обоев
    "hyprlock"          # Экран блокировки
    "hypridle"          # Управление питанием
)

packages_waybar=(
    "waybar"            # Панель
    "otf-font-awesome"  # Иконки для Waybar (имя может отличаться в зависимости от дистрибутива)
    "ttf-jetbrains-mono-nerd" # Шрифт для терминала
)

packages_other=(
    "mako"              # Демон уведомлений
    "rofi"              # Лаунчер приложений
    "dunst"             # Альтернативный демон уведомлений (на всякий случай)
    "swaylock"          # Экран блокировки (альтернативный)
    "swaybg"            # Установка обоев (альтернативный)
    "grim"              # Создание скриншотов
    "slurp"             # Выбор области для скриншотов
    "wl-clipboard"      # Работа с буфером обмена (копирование из терминала)
    "pipewire"          # Аудиосервер
    "wireplumber"       # Менеджер сессий для Pipewire
    "network-manager-applet" # Апплет для управления сетью
    "blueman"           # Менеджер Bluetooth
    "pavucontrol"       # Микшер громкости
    "brightnessctl"     # Управление яркостью
)

# Объединяем все списки в один
all_packages=("${packages_hyprland[@]}" "${packages_waybar[@]}" "${packages_other[@]}")

# --- Функция для установки пакетов ---
install_packages() {
    local pkg_manager="$1"
    local install_cmd="$2"
    local packages_to_install=()
    local failed_packages=()

    echo "🔍 Проверяем, какие пакеты уже установлены..."
    for pkg in "${all_packages[@]}"; do
        if [[ "$pkg_manager" == "pacman" ]]; then
            if ! pacman -Qi "$pkg" &> /dev/null; then
                packages_to_install+=("$pkg")
            fi
        elif [[ "$pkg_manager" == "apt" ]]; then
            if ! dpkg -s "$pkg" &> /dev/null; then
                packages_to_install+=("$pkg")
            fi
        elif [[ "$pkg_manager" == "dnf" ]]; then
            if ! rpm -q "$pkg" &> /dev/null; then
                packages_to_install+=("$pkg")
            fi
        fi
    done

    if [ ${#packages_to_install[@]} -eq 0 ]; then
        echo "✅ Все необходимые пакеты уже установлены."
        return
    fi

    echo "📦 Будет установлено ${#packages_to_install[@]} пакетов: ${packages_to_install[*]}"
    echo "⏳ Установка..."
    
    # Установка
    if [[ "$pkg_manager" == "pacman" ]]; then
        sudo pacman -S --needed --noconfirm "${packages_to_install[@]}" || failed_packages+=("${packages_to_install[@]}")
    elif [[ "$pkg_manager" == "apt" ]]; then
        sudo apt update
        sudo apt install -y "${packages_to_install[@]}" || failed_packages+=("${packages_to_install[@]}")
    elif [[ "$pkg_manager" == "dnf" ]]; then
        sudo dnf install -y "${packages_to_install[@]}" || failed_packages+=("${packages_to_install[@]}")
    fi

    if [ ${#failed_packages[@]} -gt 0 ]; then
        echo "⚠️ Не удалось установить следующие пакеты: ${failed_packages[*]}"
        echo "   Возможно, их нужно установить вручную или через AUR (для Arch)."
    else
        echo "✅ Все пакеты успешно установлены."
    fi
}

# --- Запуск установки пакетов ---
case "$distro" in
    arch)
        install_packages "pacman" "sudo pacman -S --needed --noconfirm"
        ;;
    debian)
        install_packages "apt" "sudo apt install -y"
        ;;
    fedora)
        install_packages "dnf" "sudo dnf install -y"
        ;;
    *)
        echo "⚠️ Не удалось определить дистрибутив. Пропускаем установку пакетов."
        echo "   Пожалуйста, установите следующие пакеты вручную:"
        echo "   ${all_packages[*]}"
        ;;
esac

# 2. Распаковываем архив с конфигами
if [ ! -f "$SCRIPT_DIR/$ARCHIVE_NAME" ]; then
    echo "❌ Ошибка: Архив $ARCHIVE_NAME не найден в $SCRIPT_DIR"
    exit 1
fi

echo "📦 Распаковка архива с конфигами..."
mkdir -p "$TEMP_DIR"
tar -xzf "$SCRIPT_DIR/$ARCHIVE_NAME" -C "$TEMP_DIR"

# 3. Создаем симлинки для файлов из .config
echo "🔗 Создание символьных ссылок для ~/.config..."
if [ -d "$TEMP_DIR/.config" ]; then
    for dir in "$TEMP_DIR/.config"/*; do
        if [ -d "$dir" ]; then
            base_dir=$(basename "$dir")
            target="$HOME/.config/$base_dir"
            
            mkdir -p "$(dirname "$target")"
            rm -rf "$target"
            ln -s "$(realpath "$dir")" "$target"
            echo "  ✅ $base_dir -> $target"
        fi
    done
fi

# 4. Создаем симлинки для других файлов и папок
echo "🔗 Создание символьных ссылок для других путей..."
if [ -d "$TEMP_DIR/.local/bin" ]; then
    target="$HOME/.local/bin"
    mkdir -p "$(dirname "$target")"
    rm -rf "$target"
    ln -s "$(realpath "$TEMP_DIR/.local/bin")" "$target"
    echo "  ✅ .local/bin -> $target"
fi

for rc_file in .bashrc .zshrc; do
    if [ -f "$TEMP_DIR/$rc_file" ]; then
        target="$HOME/$rc_file"
        rm -f "$target"
        ln -s "$(realpath "$TEMP_DIR/$rc_file")" "$target"
        echo "  ✅ $rc_file -> $target"
    fi
done

echo "✨ Установка завершена!"
echo "🔄 Возможно, вам потребуется перезагрузить сеанс Hyprland (Super+Shift+R) или выйти и зайти снова."
