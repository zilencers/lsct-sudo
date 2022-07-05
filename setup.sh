#!/bin/bash

SUDOERS=/etc/sudoers
PAM_SU=/etc/pam.d/su
PAM_SU_L=/etc/pam.d/su-l

install_pkgs() {
    printf "WARNING: $3 package(s) will be installed. Continue (y/N): "
    read answer
    
    if [ "$answer" == "y" ] ; then 
        echo "Installing Packages...."
        # $1 = Package Manager
        # $2 = Install Cmd
        # $3 = Package
        $@
    else
        ./lsct
    fi
}

create_user() {
    echo ""
    echo "A new user needs to be created and setup as a sudoer"
    echo "Note: It is not recommended the username be adm, admin or administrator."
    echo "      Usernames may contain letters, numbers, and special characters."
    printf "Please enter a username: "
    read username

    echo ""
    echo "Adding user..."
    useradd $username -m
    passwd $username

    # If the user is not a member of wheel, software using 
    # Polkit may ask to authenticate using the root password 
    # instead of the user password.

    echo "Adding user to wheel..."
    usermod -a -G wheel $username  
}

edit_sudoers() {
    echo "Checking for existing sudoers backup file..."
    [ -f $SUDOERS.bak ] && rm $SUDOERS.bak

    echo "Making backup of $SUDOERS..."
    cp $SUDOERS $SUDOERS.bak

    echo "Modifying $SUDOERS..."
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' $SUDOERS
    check_sudoers
}

check_sudoers() {
    printf "Checking for valid sudoers file..."
    result=$(visudo -c $SUDOERS | grep -i ok)
    echo $result

    if [ ! $result ] ; then
        echo "Error: sudoers file is not valid"
        echo "Run: 'visudo -c /etc/sudoers.bak' for more information"
	read
        exit 1 
    fi
}

config_pam_su() {
    echo "Configuring $PAM_SU...."
    printf "Configuring $PAM_SU_L..."

    # Require user to be in the wheel group in to use su
    sed -i 's/##auth           required        pam_wheel.so use_uid/auth           required        pam_wheel.so use_uid/' $PAM_SU
    sed -i 's/#auth           required        pam_wheel.so use_uid/auth           required        pam_wheel.so use_uid/' $PAM_SU_l

    echo "Complete"
}

disable_root() {
    echo ""
    echo "This portion of the setup will lock the root account."
    echo "It is HIGHLY recommended that you switch to a new tty"
    echo "and test the new user account. After confirming the new"
    echo "user account is able to login, make sure sudo is working" 
    echo "properly."
    echo "Switch to a new tty by holding CTRL-ALT and one of the"
    echo "function keys. Hint: CTRL-ALT-F3"
    printf "Connected to tty: "
    tty

    echo ""
    printf "Continue with locking the root account? (y/N): "
    read answer

    if [ "$answer" == "y" ] ; then
	echo "Locking root account..."
        passwd -l root
	echo "The root account may be unlocked at any time with:"
	echo "sudo passwd -u root"
    fi

    echo "Sudo setup is now complete... "
    echo "Press any key to continue"
}

title() {
    echo "----------------------------------------------"
    echo "                Sudo Setup"
    echo "----------------------------------------------"
    echo ""
}

main() {
   title
   install_pkgs $@
   create_user
   edit_sudoers
   config_pam_su
   disable_root
}

main $@

