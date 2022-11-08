::Mount drive to current location
@pushd %~dp0

::Run PSADT
Deploy-Application.exe -DeploymentType "Uninstall"

::Unmount drive
@popd

