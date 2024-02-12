
# Kismet Installation and Configuration Script

## Usage

1. Run the script:
    ```bash
    sudo bash kismet-setup.sh
    ```

## Steps Performed by the Script

1. Downloads and installs the Kismet repository key.
2. Adds the Kismet repository to the system's sources.list.
3. Updates the package information.
4. Installs Kismet and Aircrack-ng.
5. Adds the current user to the Kismet group.
6. Enables the Kismet service.
7. Modifies the Kismet service ExecStart line to include "--override wardrive."
8. Reloads systemd manager to apply changes.
9. Puts all available wireless interfaces into monitor mode using Aircrack-ng.
10. Adds all successful wireless interfaces into config to be used as data source.  

## Additional Information

- The Kismet web UI can be accessed at: `http://<machine-ip>:2501`
- Setup the user and reboot the machine for all changes to take effect.
- This is a work in progress so be wary. 
