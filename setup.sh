#!/bin/bash

SUDOERS=/etc/sudoers
PAM_SU=/etc/pam.d/su
PAM_SU_L=/etc/pam.d/su-l
SECTTY=/etc/securetty
USERNAME=""

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
    read USERNAME

    echo ""
    echo "Adding user..."
    useradd $USERNAME -m
    passwd $USERNAME

    # If the user is not a member of wheel, software using 
    # Polkit may ask to authenticate using the root password 
    # instead of the user password.

    echo "Adding user to wheel..."
    usermod -a -G wheel $USERNAME  
}

edit_sudoers() {
    echo "Checking for existing sudoers backup file..."
    [ -f $SUDOERS.bak ] && rm $SUDOERS.bak

    echo "Making backup of $SUDOERS..."
    cp $SUDOERS $SUDOERS.bak

    echo "Modifying $SUDOERS..."
    chmod 640 $SUDOERS
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' $SUDOERS
    chmod 440 $SUDOERS
    check_sudoers
}

check_sudoers() {
    printf "Checking for valid sudoers file..."
    result=$(visudo -c $SUDOERS | grep -i ok)
    echo $result

    if [ ! "$result" ] ; then
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
    sed -i 's/#auth           required        pam_wheel.so use_uid/auth           required        pam_wheel.so use_uid/' $PAM_SU_L

    echo "Complete"
}

disable_root() {
    echo ""
    echo "This portion of the setup will disable root login."
    echo "It is HIGHLY recommended that you switch to a new tty"
    echo "and test the new user account. After confirming the new"
    echo "user account is able to login, make sure sudo is working" 
    echo "properly."
    echo "Switch to a new tty by holding CTRL-ALT and one of the"
    echo "function keys. Hint: CTRL-ALT-F3"
    printf "Connected to tty: "
    tty

    echo ""
    printf "Continue with disabling root login? (y/N): "
    read answer

    touch $SECTTY.bak
    echo "#console" >> $SECTTY.bak 
    echo "#tty1" >> $SECTTY.bak 
    echo "#tty2" >> $SECTTY.bak 
    echo "#tty3" >> $SECTTY.bak 
    echo "#tty4" >> $SECTTY.bak 
    echo "#tty5" >> $SECTTY.bak 
    echo "#tty6" >> $SECTTY.bak 
    echo "#ttyS0" >> $SECTTY.bak 
    echo "#hvc0" >> $SECTTY.bak
    mv $SECTTY.bak $SECTTY 

    echo "Sudo setup is now complete... "
    echo "Press any key to continue"
    read
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

