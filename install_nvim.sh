#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Minimum required Neovim version
MIN_NVIM_VERSION="0.11.0"
BREW="${BREW:-brew}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

version_ge() {
    # Compare versions: returns 0 if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

check_nvim_version() {
    if ! command -v nvim &> /dev/null; then
        return 1
    fi
    
    local version
    log_info "$(nvim --version | head -n1)"
    version=$(nvim --version | head -n1 | sed -E 's/.*v([0-9]+\.[0-9]+\.[0-9]+)/\1/' || echo "0.0.0")
    
    log_info "Found Neovim version: $version"
    
    if version_ge "$version" "$MIN_NVIM_VERSION"; then
        log_success "Neovim version $version meets minimum requirement ($MIN_NVIM_VERSION)"
        return 0
    else
        log_warning "Neovim version $version is below minimum requirement ($MIN_NVIM_VERSION)"
        return 1
    fi
}

check_prerequisite() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        log_success "$name is installed"
        return 0
    else
        log_error "$name is not installed"
        return 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=0
    
    check_prerequisite "git" "Git" || missing=1
    check_prerequisite "curl" "curl" || missing=1
    
    # Check for C compiler (gcc or clang)
    if command -v gcc &> /dev/null || command -v clang &> /dev/null; then
        log_success "C compiler is installed"
    else
        log_error "C compiler (gcc or clang) is not installed"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "Missing prerequisites. Please install them first."
        return 1
    fi
    
    return 0
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unsupported"
    fi
}

detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

install_nerd_font_macos() {
    log_info "Installing JetBrains Mono Nerd Font on macOS..."
    
    if ! command -v "$BREW" &> /dev/null; then
        log_warning "Homebrew is not available for font installation"
        print_manual_font_instructions
        return 1
    fi
    
    if "$BREW" install --cask font-jetbrains-mono-nerd-font; then
        log_success "JetBrains Mono Nerd Font installed successfully!"
        return 0
    else
        log_warning "Failed to install Nerd Font via Homebrew"
        print_manual_font_instructions
        return 1
    fi
}

install_nerd_font_linux() {
    log_info "Installing JetBrains Mono Nerd Font on Linux..."
    
    local font_dir="$HOME/.local/share/fonts"
    local font_name="JetBrainsMono"
    local download_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Create fonts directory if it doesn't exist
    mkdir -p "$font_dir"
    
    log_info "Downloading JetBrains Mono Nerd Font..."
    if ! curl -fLo "$temp_dir/$font_name.zip" "$download_url"; then
        log_warning "Failed to download Nerd Font"
        rm -rf "$temp_dir"
        print_manual_font_instructions
        return 1
    fi
    
    log_info "Extracting fonts..."
    if ! unzip -q "$temp_dir/$font_name.zip" -d "$temp_dir/$font_name"; then
        log_warning "Failed to extract font archive"
        rm -rf "$temp_dir"
        print_manual_font_instructions
        return 1
    fi
    
    log_info "Installing fonts to $font_dir..."
    find "$temp_dir/$font_name" -name "*.ttf" -exec cp {} "$font_dir/" \;
    
    # Clean up
    rm -rf "$temp_dir"
    
    log_info "Refreshing font cache..."
    if command -v fc-cache &> /dev/null; then
        if fc-cache -fv &> /dev/null; then
            log_success "JetBrains Mono Nerd Font installed successfully!"
            return 0
        else
            log_warning "Font cache refresh failed, but fonts were installed"
            log_info "You may need to restart your terminal or run: fc-cache -fv"
            return 0
        fi
    else
        log_warning "fc-cache not found. Fonts installed but cache not refreshed"
        log_info "You may need to restart your terminal for fonts to be available"
        return 0
    fi
}

print_manual_font_instructions() {
    log_info "Manual Nerd Font installation instructions:"
    echo ""
    echo "  1. Visit: https://www.nerdfonts.com/font-downloads"
    echo "  2. Download 'JetBrains Mono' or your preferred Nerd Font"
    echo "  3. Extract the downloaded archive"
    echo "  4. Install the fonts:"
    echo "     - macOS: Double-click .ttf files and click 'Install Font'"
    echo "     - Linux: Copy .ttf files to ~/.local/share/fonts/ and run 'fc-cache -fv'"
    echo "  5. Configure your terminal to use the installed Nerd Font"
    echo ""
}

install_nerd_fonts() {
    log_info "Starting Nerd Font installation..."
    echo ""
    
    local os
    os=$(detect_os)
    
    case "$os" in
        macos)
            install_nerd_font_macos
            ;;
        linux)
            install_nerd_font_linux
            ;;
        *)
            log_warning "Cannot automatically install fonts on this OS"
            print_manual_font_instructions
            return 1
            ;;
    esac
}

configure_zshrc() {
    log_info "Configuring zsh environment variables..."
    
    local zshrc="$HOME/.zshrc"
    local editor_export="export EDITOR=nvim"
    local visual_export="export VISUAL=nvim"
    
    # Check if zsh is available
    if ! command -v zsh &> /dev/null; then
        log_info "zsh is not installed, skipping zshrc configuration"
        return 0
    fi
    
    # Check if EDITOR export already exists
    local editor_exists=0
    local visual_exists=0
    
    if [ -f "$zshrc" ]; then
        if grep -q "^export EDITOR=nvim" "$zshrc" 2>/dev/null; then
            editor_exists=1
        fi
        if grep -q "^export VISUAL=nvim" "$zshrc" 2>/dev/null; then
            visual_exists=1
        fi
    fi
    
    # If both already exist, skip
    if [ $editor_exists -eq 1 ] && [ $visual_exists -eq 1 ]; then
        log_success "EDITOR and VISUAL are already configured in ~/.zshrc"
        return 0
    fi
    
    # Create timestamped backup if file exists
    if [ -f "$zshrc" ]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup="$zshrc.backup.$timestamp"
        
        log_info "Creating backup: $backup"
        cp "$zshrc" "$backup"
        log_success "Backup created successfully"
    else
        log_info "Creating new ~/.zshrc file"
        touch "$zshrc"
    fi
    
    # Append exports if they don't exist
    if [ $editor_exists -eq 0 ]; then
        echo "$editor_export" >> "$zshrc"
        log_success "Added EDITOR=nvim to ~/.zshrc"
    fi
    
    if [ $visual_exists -eq 0 ]; then
        echo "$visual_export" >> "$zshrc"
        log_success "Added VISUAL=nvim to ~/.zshrc"
    fi
    
    # Source the updated file to apply changes immediately
    log_info "Applying changes to current shell..."
    if [ -n "${ZSH_VERSION:-}" ]; then
        # We're running in zsh
        # shellcheck disable=SC1090
        source "$zshrc"
        log_success "Changes applied to current zsh session"
    else
        log_info "Not running in zsh, changes will take effect in new zsh sessions"
    fi
    
    log_success "zshrc configuration completed"
    return 0
}

install_packer() {
    log_info "Installing Packer.nvim plugin manager..."
    
    local packer_dir="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
    
    # Check if Packer is already installed
    if [ -d "$packer_dir" ]; then
        log_success "Packer.nvim is already installed at $packer_dir"
        return 0
    fi
    
    # Create parent directory if it doesn't exist
    local parent_dir="$HOME/.local/share/nvim/site/pack/packer/start"
    mkdir -p "$parent_dir"
    
    log_info "Cloning Packer.nvim from GitHub..."
    if git clone --depth 1 https://github.com/wbthomason/packer.nvim "$packer_dir"; then
        log_success "Packer.nvim installed successfully!"
        return 0
    else
        log_error "Failed to clone Packer.nvim"
        return 1
    fi
}

create_init_lua() {
    log_info "Creating Neovim configuration file..."
    
    local nvim_config_dir="$HOME/.config/nvim"
    local init_lua="$nvim_config_dir/init.lua"
    
    # Create config directory if it doesn't exist
    mkdir -p "$nvim_config_dir"
    
    # Check if init.lua already exists
    if [ -f "$init_lua" ]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup="$init_lua.backup.$timestamp"
        
        log_info "Backing up existing init.lua to $backup"
        cp "$init_lua" "$backup"
        log_success "Backup created successfully"
    fi
    
    log_info "Writing init.lua configuration..."
    
    cat > "$init_lua" << 'EOF'
-- Bootstrap Packer.nvim
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

-- Packer configuration
require('packer').startup(function(use)
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'

  -- Treesitter for better syntax highlighting
  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup {
        -- Ensure these parsers are installed
        ensure_installed = {
          'rust',
          'yaml',
          'json',
          'bash',
          'markdown',
          'lua',
        },
        
        -- Install parsers synchronously (only applied to `ensure_installed`)
        sync_install = false,
        
        -- Automatically install missing parsers when entering buffer
        auto_install = true,
        
        -- Enable syntax highlighting
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        
        -- Enable indentation
        indent = {
          enable = true,
        },
      }
    end
  }

  -- Automatically set up configuration after cloning packer.nvim
  if packer_bootstrap then
    require('packer').sync()
  end
end)
EOF
    
    if [ $? -eq 0 ]; then
        log_success "init.lua created successfully at $init_lua"
        return 0
    else
        log_error "Failed to create init.lua"
        return 1
    fi
}

verify_treesitter_parsers() {
    log_info "Verifying tree-sitter parser installation..."
    
    # Expected parsers from the config
    local expected_parsers=("rust" "yaml" "json" "bash" "markdown" "lua")
    local missing_parsers=()
    local installed_count=0
    
    # Check each parser by trying to query tree-sitter info
    for parser in "${expected_parsers[@]}"; do
        # Check if the parser directory exists
        local parser_dir="$HOME/.local/share/nvim/site/pack/packer/start/nvim-treesitter/parser"
        
        # Use nvim to check if the parser is actually loaded
        if nvim --headless -c "lua if pcall(vim.treesitter.language.add, '$parser') then vim.cmd('quit') else vim.cmd('cquit') end" 2>/dev/null; then
            log_success "Tree-sitter parser installed: $parser"
            ((installed_count++))
        else
            log_warning "Tree-sitter parser missing or failed: $parser"
            missing_parsers+=("$parser")
        fi
    done
    
    echo ""
    if [ ${#missing_parsers[@]} -eq 0 ]; then
        log_success "All tree-sitter parsers installed successfully! ($installed_count/${#expected_parsers[@]})"
        return 0
    else
        log_warning "Some tree-sitter parsers could not be verified (${#missing_parsers[@]}/${#expected_parsers[@]} missing)"
        log_info "Missing parsers: ${missing_parsers[*]}"
        log_info "These parsers may install automatically when you first edit relevant file types"
        return 1
    fi
}

verify_nvim_installation() {
    log_info "Running post-installation verification..."
    echo ""
    
    # Verify nvim command is available
    log_info "Checking Neovim installation..."
    if ! command -v nvim &> /dev/null; then
        log_error "Neovim command not found in PATH"
        return 1
    fi
    
    # Verify nvim version
    log_info "Verifying Neovim version..."
    local version_output
    version_output=$(nvim --version 2>&1)
    
    if [ $? -eq 0 ]; then
        local version
        version=$(echo "$version_output" | head -n1 | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "Neovim version: $version"
        
        # Show additional version info
        echo "$version_output" | head -n3 | while IFS= read -r line; do
            echo "  $line"
        done
    else
        log_error "Failed to get Neovim version"
        return 1
    fi
    
    echo ""
    
    # Verify Packer installation
    log_info "Checking Packer.nvim installation..."
    local packer_dir="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
    if [ -d "$packer_dir" ]; then
        log_success "Packer.nvim is installed"
    else
        log_warning "Packer.nvim directory not found"
    fi
    
    echo ""
    
    # Verify tree-sitter installation
    log_info "Checking nvim-treesitter plugin..."
    local treesitter_dir="$HOME/.local/share/nvim/site/pack/packer/start/nvim-treesitter"
    if [ -d "$treesitter_dir" ]; then
        log_success "nvim-treesitter plugin is installed"
        echo ""
        verify_treesitter_parsers
    else
        log_warning "nvim-treesitter plugin directory not found"
        log_info "The plugin may still be downloading"
        return 1
    fi
    
    return 0
}

print_success_message() {
    echo ""
    echo "========================================================================"
    log_success "Neovim installation and configuration completed successfully!"
    echo "========================================================================"
    echo ""
    echo "📦 What was installed:"
    echo "  ✓ Neovim $(nvim --version | head -n1 | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' || echo '')"
    echo "  ✓ Packer.nvim plugin manager"
    echo "  ✓ nvim-treesitter with parsers for: Rust, YAML, JSON, Bash, Markdown, Lua"
    echo "  ✓ Configuration file: ~/.config/nvim/init.lua"
    
    if [ -f "$HOME/.zshrc" ]; then
        if grep -q "export EDITOR=nvim" "$HOME/.zshrc" 2>/dev/null; then
            echo "  ✓ Environment variables: EDITOR and VISUAL set to nvim"
        fi
    fi
    
    echo ""
    echo "🚀 Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. Open Neovim: nvim"
    echo "  3. If you see any plugin errors, run: :PackerSync"
    echo "  4. Configure your terminal to use a Nerd Font for proper icon display"
    echo ""
    echo "📚 Useful commands:"
    echo "  • :PackerSync     - Update all plugins"
    echo "  • :PackerStatus   - Check plugin status"
    echo "  • :TSUpdate       - Update tree-sitter parsers"
    echo "  • :TSInstallInfo  - Show installed parsers"
    echo "  • :checkhealth    - Run Neovim health checks"
    echo ""
    echo "📖 Learn more:"
    echo "  • Neovim docs: :help"
    echo "  • Packer: https://github.com/wbthomason/packer.nvim"
    echo "  • Tree-sitter: https://github.com/nvim-treesitter/nvim-treesitter"
    echo ""
}

print_failure_message() {
    local verification_failed=$1
    
    echo ""
    echo "========================================================================"
    log_warning "Installation completed with some issues"
    echo "========================================================================"
    echo ""
    
    if [ "$verification_failed" = "true" ]; then
        log_info "The core installation succeeded, but verification found some issues."
        echo ""
    fi
    
    echo "⚠️  What might be wrong:"
    echo "  • Some plugins or parsers may not have installed completely"
    echo "  • Tree-sitter parsers might still be compiling"
    echo "  • Network issues may have interrupted downloads"
    echo ""
    echo "🔧 Troubleshooting steps:"
    echo "  1. Open Neovim: nvim"
    echo "  2. Run: :PackerSync"
    echo "  3. Wait for all installations to complete"
    echo "  4. Run: :TSUpdate all"
    echo "  5. Run: :checkhealth"
    echo "  6. Restart Neovim"
    echo ""
    echo "  If problems persist:"
    echo "  • Check that you have a C compiler: gcc --version or clang --version"
    echo "  • Check internet connectivity"
    echo "  • Review Neovim logs: ~/.local/share/nvim/"
    echo ""
    echo "📖 Get help:"
    echo "  • Neovim docs: :help"
    echo "  • Packer issues: https://github.com/wbthomason/packer.nvim/issues"
    echo "  • Tree-sitter issues: https://github.com/nvim-treesitter/nvim-treesitter/issues"
    echo ""
}

install_packer_plugins() {
    log_info "Installing Packer plugins and Treesitter parsers..."
    
    log_info "This will run Neovim in headless mode to install plugins..."
    log_info "Please wait, this may take a minute or two..."
    echo ""
    
    # Run Neovim headless to install plugins
    # Capture output for debugging but don't show unless there's an error
    local output
    local exit_code
    
    output=$(nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync' 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "Plugin installation completed!"
        
        # Give tree-sitter a moment to compile parsers
        log_info "Waiting for tree-sitter parsers to compile..."
        sleep 3
        
        return 0
    else
        log_warning "Plugin installation may have encountered issues"
        log_info "Installation output:"
        echo "$output" | tail -n 20
        return 1
    fi
}

install_macos() {
    log_info "Installing Neovim on macOS..."
    
    if ! command -v "$BREW" &> /dev/null; then
        log_info "Homebrew is not installed globally. Trying it locally:"
        if [[ -f "$HOME/homebrew/bin/brew" ]]; then
            log_info "Found a file in $HOME/homebrew/bin/brew. Will try it..."
            BREW="$HOME/homebrew/bin/brew"
        else
            log_error "Homebrew is not installed. Please install Homebrew first:"
            log_error "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            log_error "Or override the variable BREW=.... with the location:"
            log_error "  BREW=$HOME/homebrew/bin/homebrew $0 ...."
            return 1
        fi
    fi
    
    log_info "Updating Homebrew..."
    "$BREW" update
    
    log_info "Installing Neovim via Homebrew..."
    "$BREW" install neovim
    
    return 0
}

install_linux_apt() {
    log_info "Installing Neovim on Debian/Ubuntu (apt)..."
    
    if ! command -v apt-get &> /dev/null; then
        log_error "apt-get is not available"
        return 1
    fi
    
    log_info "Updating package lists..."
    sudo apt-get update
    
    # Check if we can get a recent version from the repository
    log_info "Installing Neovim via apt-get..."
    sudo apt-get install -y neovim
    
    # If the installed version is too old, suggest snap or AppImage
    if ! check_nvim_version; then
        log_warning "The apt repository version is outdated."
        log_info "Attempting to install via snap for a newer version..."
        
        if command -v snap &> /dev/null; then
            sudo apt-get remove -y neovim
            sudo snap install nvim --classic
        else
            log_warning "Snap is not available. You may need to install Neovim manually:"
            log_warning "  https://github.com/neovim/neovim/releases"
        fi
    fi
    
    return 0
}

install_linux_dnf() {
    log_info "Installing Neovim on Fedora/RHEL (dnf)..."
    
    if ! command -v dnf &> /dev/null; then
        log_error "dnf is not available"
        return 1
    fi
    
    log_info "Installing Neovim via dnf..."
    sudo dnf install -y neovim
    
    return 0
}

install_linux_yum() {
    log_info "Installing Neovim on RHEL/CentOS (yum)..."
    
    if ! command -v yum &> /dev/null; then
        log_error "yum is not available"
        return 1
    fi
    
    # Try to enable EPEL for newer versions
    log_info "Enabling EPEL repository..."
    sudo yum install -y epel-release || true
    
    log_info "Installing Neovim via yum..."
    sudo yum install -y neovim
    
    return 0
}

install_linux_snap() {
    log_info "Installing Neovim via snap..."
    
    if ! command -v snap &> /dev/null; then
        log_error "snap is not available"
        return 1
    fi
    
    sudo snap install nvim --classic
    
    return 0
}

install_linux() {
    log_info "Installing Neovim on Linux..."
    
    local distro
    distro=$(detect_linux_distro)
    
    log_info "Detected Linux distribution: $distro"
    
    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            install_linux_apt
            ;;
        fedora)
            install_linux_dnf
            ;;
        rhel|centos|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                install_linux_dnf
            else
                install_linux_yum
            fi
            ;;
        arch|manjaro)
            log_info "Installing Neovim via pacman..."
            sudo pacman -Syu --noconfirm neovim
            ;;
        opensuse*|sles)
            log_info "Installing Neovim via zypper..."
            sudo zypper install -y neovim
            ;;
        *)
            log_warning "Distribution not specifically supported, trying generic methods..."
            
            # Try common package managers in order of preference
            if command -v snap &> /dev/null; then
                install_linux_snap
            elif command -v apt-get &> /dev/null; then
                install_linux_apt
            elif command -v dnf &> /dev/null; then
                install_linux_dnf
            elif command -v yum &> /dev/null; then
                install_linux_yum
            else
                log_error "No supported package manager found"
                log_error "Please install Neovim manually from: https://github.com/neovim/neovim/releases"
                return 1
            fi
            ;;
    esac
    
    return 0
}

main() {
    log_info "Neovim Installation Script"
    log_info "Minimum required version: $MIN_NVIM_VERSION"
    echo ""
    
    # Check if Neovim is already installed and meets version requirement
    if check_nvim_version; then
        log_success "Neovim is already installed and meets the version requirement!"
        
        # Still offer to install Nerd Fonts
        echo ""
        install_nerd_fonts
        
        # Configure zshrc
        echo ""
        configure_zshrc
        
        # Install Packer.nvim
        echo ""
        install_packer
        
        # Create init.lua configuration
        echo ""
        create_init_lua
        
        # Install Packer plugins
        echo ""
        if install_packer_plugins; then
            # Run verification
            echo ""
            if verify_nvim_installation; then
                print_success_message
                exit 0
            else
                print_failure_message "true"
                exit 1
            fi
        else
            print_failure_message "false"
            exit 1
        fi
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    echo ""
    
    # Detect OS
    local os
    os=$(detect_os)
    
    log_info "Detected OS: $os"
    
    case "$os" in
        macos)
            if install_macos; then
                echo ""
                log_info "Verifying installation..."
                if check_nvim_version; then
                    log_success "Neovim installation completed successfully!"
                    
                    # Install Nerd Fonts
                    echo ""
                    install_nerd_fonts
                    
                    # Configure zshrc
                    echo ""
                    configure_zshrc
                    
                    # Install Packer.nvim
                    echo ""
                    install_packer
                    
                    # Create init.lua configuration
                    echo ""
                    create_init_lua
                    
                    # Install Packer plugins
                    echo ""
                    if install_packer_plugins; then
                        # Run verification
                        echo ""
                        if verify_nvim_installation; then
                            print_success_message
                            exit 0
                        else
                            print_failure_message "true"
                            exit 1
                        fi
                    else
                        print_failure_message "false"
                        exit 1
                    fi
                else
                    log_error "Neovim was installed but version check failed"
                    exit 1
                fi
            else
                log_error "Failed to install Neovim on macOS"
                exit 1
            fi
            ;;
        linux)
            if install_linux; then
                echo ""
                log_info "Verifying installation..."
                if check_nvim_version; then
                    log_success "Neovim installation completed successfully!"
                    
                    # Install Nerd Fonts
                    echo ""
                    install_nerd_fonts
                    
                    # Configure zshrc
                    echo ""
                    configure_zshrc
                    
                    # Install Packer.nvim
                    echo ""
                    install_packer
                    
                    # Create init.lua configuration
                    echo ""
                    create_init_lua
                    
                    # Install Packer plugins
                    echo ""
                    if install_packer_plugins; then
                        # Run verification
                        echo ""
                        if verify_nvim_installation; then
                            print_success_message
                            exit 0
                        else
                            print_failure_message "true"
                            exit 1
                        fi
                    else
                        print_failure_message "false"
                        exit 1
                    fi
                else
                    log_error "Neovim was installed but version check failed"
                    log_warning "You may need to install a newer version manually:"
                    log_warning "  https://github.com/neovim/neovim/releases"
                    exit 1
                fi
            else
                log_error "Failed to install Neovim on Linux"
                exit 1
            fi
            ;;
        unsupported)
            log_error "Unsupported operating system: $OSTYPE"
            log_error "This script supports macOS and Linux only"
            log_error "Please install Neovim manually from: https://github.com/neovim/neovim/releases"
            exit 1
            ;;
    esac
}

main "$@"
