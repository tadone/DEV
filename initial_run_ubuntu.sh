#!/bin/bash -x

# Script to be run as root to setup new user and install essential programs with customization

NEWUSER=$1 # 1st Variable to be passed when running this script
PASS=$2 # 2nd Variable to be passed when running this script

declare -r GITHUB_REPOSITORY='tadone/dotfiles-tad'
declare -r DOTFILES_ORIGIN="git@github.com:$GITHUB_REPOSITORY.git"
declare -r DOTFILES_TARBALL_URL="https://github.com/$GITHUB_REPOSITORY/tarball/master"
declare DOTFILES_DIR="/home/$NEWUSER/dotfiles"
# ----------------------------------------------------------------------
# | Helper Functions                                                   |
# ----------------------------------------------------------------------

execute() {
    eval "$1" &> /dev/null
    print_result $? "${2:-$1}"
}

vars() {
	if [ "$NEWUSER" == '' ] || [ "$PASS" == '' ]; then 
	#if [ $# -ne 2 ]; then
		print_error "Please provide username and password with this script in form of: $0 newusername password"
		return 1	
	fi
	return 0
}

ask_for_sudo() {

    # Ask for the administrator password upfront
    sudo -v &> /dev/null

    # Update existing `sudo` time stamp until this script has finished
    # https://gist.github.com/cowboy/3118588
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done &> /dev/null &

}

user_exists() {
	grep -q "$NEWUSER" /etc/passwd
	if [ $? -eq 0 ]; then 
		print_error "The $NEWUSER user already exists. Please use a different username"
		return 1
	fi
	return 0
}

add_user() {
	execute "useradd $NEWUSER -s /bin/zsh -m -G sudo"
	#useradd -p `mkpasswd "$PASS"` -d /home/"$NEWUSER" -m -G sudo -s /bin/zsh "$NEWUSER"
	execute "echo $NEWUSER:$PASS | chpasswd"
}

download() {

    local url="$1"
    local output="$2"

    if command -v 'curl' &> /dev/null; then

        curl -LsSo "$output" "$url" &> /dev/null
        #     │││└─ write output to file
        #     ││└─ show error messages
        #     │└─ don't show the progress meter
        #     └─ follow redirects

        return $?

    elif command -v 'wget' &> /dev/null; then

        wget -qO "$output" "$url" &> /dev/null
        #     │└─ write output to file
        #     └─ don't show output

        return $?
    fi

    return 1

}

cmd_exists() {
    command -v "$1" &> /dev/null
    return $?
}

print_error() {
    print_in_red "  [✖] $1 $2\n"
}

print_in_green() {
    printf "\e[0;32m$1\e[0m"
}

print_in_purple() {
    printf "\e[0;35m$1\e[0m"
}

print_in_red() {
    printf "\e[0;31m$1\e[0m"
}

print_in_yellow() {
    printf "\e[0;33m$1\e[0m"
}

print_info() {
    print_in_purple "\n $1\n\n"
}

print_question() {
    print_in_yellow "  [?] $1"
}

print_result() {
    [ $1 -eq 0 ] \
        && print_success "$2" \
        || print_error "$2"

    return $1
}

print_success() {
    print_in_green "  [✔] $1\n"
}

get_os() {

    declare -r OS_NAME="$(uname -s)"
    local os=''

    if [ "$OS_NAME" == "Darwin" ]; then
        os='osx'
    elif [ "$OS_NAME" == "Linux" ] && [ -e "/etc/lsb-release" ]; then
        os='ubuntu'
    else
        os="$OS_NAME"
    fi

    printf "%s" "$os"

}


download_dotfiles() {

	local tmpFile="$(mktemp /tmp/XXXXX)"

	download "$DOTFILES_TARBALL_URL" "$tmpFile"
    print_result $? 'Download archive' 'true'
    printf '\n'

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Create `dotfiles` directory

    mkdir -p "$DOTFILES_DIR"
    print_result $? "Create '$DOTFILES_DIR'" 'true'

    # Extract archive in the `dotfiles` directory

    extract "$tmpFile" "$DOTFILES_DIR"
    print_result $? 'Extract archive' 'true'

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Remove archive

    rm -rf "$tmpFile"
    print_result $? 'Remove archive'

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    cd "$DOTFILES_DIR"

}

vim_plugins() {

	rm -rf /home/$NEWUSER/.vim/plugins/Vundle.vim &> /dev/null \
        && git clone https://github.com/gmarik/Vundle.vim.git /home/$NEWUSER/.vim/plugins/Vundle.vim &> /dev/null \
        && printf "\n" | vim +PluginInstall +qall 2> /dev/null
        #     └─ simulate the ENTER keypress for
        #        the case where there are warnings
        chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.vim
    print_result $? 'Install Vim plugins'
}

install_prezto() {
 	git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-/home/$NEWUSER}/.zprezto"

	chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.zprezto
	cd /home/$NEWUSER/.zprezto
		declare -a FILES_TO_SYMLINK=(
		zlogin
		zlogout
		zpreztorc
		zprofile
		zshenv
		zshrc
		)

	local i=''
	local sourceFile=''
    local targetFile=''

    for i in ${FILES_TO_SYMLINK[@]}; do
    	sourceFile="/home/$NEWUSER/.zprezto/runcoms/$i"
    	targetFile="/home/$NEWUSER/.$(printf "%s" "$i")"
    	execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
    done
    print_result $? 'Install Prezto'
}

extract() {

    local archive="$1"
    local outputDir="$2"

    if command -v 'tar' &> /dev/null; then
        tar -zxf "$archive" --strip-components 1 -C "$outputDir"
        return $?
    fi

    return 0

}

verify_os() {
	declare -r OS_NAME=$(uname -s)

	if [ "$OS_NAME" != "Linux" ]; then
		print_error 'Sorry, this script is intended for Linux only!'
		return 1
	fi

	return 0
}

run_as_sudo() {
	SUDO=''
	if (( $EUID != 0 )); then
	    SUDO='sudo'
	fi
}

install_package() {

    declare -r PACKAGE="$2"
    declare -r PACKAGE_READABLE_NAME="$1"

    if ! package_is_installed "$PACKAGE"; then
        execute "apt-get install -y $PACKAGE" "$PACKAGE_READABLE_NAME"
        #                                      suppress output ─┘│
        #            assume "yes" as the answer to all prompts ──┘
    else
        print_success "$PACKAGE_READABLE_NAME"
    fi

}

package_is_installed() {
    dpkg -s "$1" &> /dev/null
}

update() {

    # Resynchronize the package index files from their sources
    execute 'apt-get update -y' 'update'

}

upgrade() {

    # Install the newest versions of all packages installed
    execute 'apt-get upgrade -y' 'upgrade'

}

create_symlinks() {

	chown -R $NEWUSER:$NEWUSER $DOTFILES_DIR
	cd $DOTFILES_DIR
		declare -a FILES_TO_SYMLINK=(
		#bashrc
		zshrc
		zpreztorc
		vimrc
		)

	local i=''
	local sourceFile=''
    local targetFile=''

    for i in ${FILES_TO_SYMLINK[@]}; do
    	sourceFile="$DOTFILES_DIR/$i"
    	targetFile="/home/$NEWUSER/.$(printf "%s" "$i")"
    	execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
    done
}

enable_fw_rules() {
	execute "ufw default deny incoming"
	execute "ufw allow 22" # SSH Port
	execute "ufw allow 80" # Http Port
	execute "ufw allow 443" # Https port
    #execute "ufw allow 3306" # MySQL port
	execute "ufw disable"
	execute "ufw enable"
}


# ----------------------------------------------------------------------
# | Main                                                               |
# ----------------------------------------------------------------------

main() {	

	# All variables supplied
	vars || exit 1

	# Ensure it's linux
	verify_os || exit 1

	# Make sure to run as sudo
    ask_for_sudo

    # Check if user already exists
    user_exists || exit 1

    # Update System
    print_info 'System update & upgrade'
    #update && upgrade

    # Install essentials
    print_info 'Installing essential programs'
    install_package 'Vim' 'vim'
    install_package 'Git' 'git'
    install_package 'ZSH' 'zsh'
    #install_package 'Unattended Upgrades' 'unattended-upgrades'
    install_package 'Logwatch' 'logwatch'
    install_package 'Htop' 'htop'
    install_package 'fail2ban' 'fail2ban'
    install_package 'UFW' 'ufw'
    install_package 'Exim4' 'exim4'
    install_package 'Wget' 'wget'
    install_package 'Unzip' 'unzip'
    #install_package 'nagios' 'nagios'

    # Add new user with sudo group
    print_info 'Adding new user'
    add_user || exit 1

    # Setup the `dotfiles` if needed

    if ! cmd_exists 'git' \
        || [ "$(git config --get remote.origin.url)" != "$DOTFILES_ORIGIN" ]; then

        print_info 'Download and extract archive'
        download_dotfiles

        
    fi

    # Install VIM Plugins

    print_info 'Install VIM Plugins'

    vim_plugins

	# Install zprezto
	if ! cmd_exists 'git' || [ ! -e "/home/$NEWUSER/.zpreztorc" ]; then

	print_info 'Install Prezto'
		
	install_prezto

	fi
			
	# Link custom dotfiles
	print_info 'Create symlinks'
    
    create_symlinks
	
	# Add firewall Rules
	print_info 'Adding Firewall Rules'

	enable_fw_rules

	# Ensure correct ownership for the new user
	execute "chown -R $NEWUSER:$NEWUSER /home/$NEWUSER"

# Manage logs

}

main