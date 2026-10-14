Name:           %NAME%
Version:        %VERSION%
Release:        1%{?dist}
Summary:        binary built from source
License:        %LICENSE%
URL:            %URL%
BuildArch:      %{_arch}

%description
binary built from source.

%prep
%build
%install
mkdir -p %{buildroot}%INSTALLATION_TARGET_DIR%
install -m 0755 %BUILT_FILE% %{buildroot}%INSTALLATION_TARGET_DIR%/%INSTALLATION_TARGET_NAME%

%files
%INSTALLATION_TARGET_DIR%/%INSTALLATION_TARGET_NAME%

%changelog
* Thu Jan 30 2026 i2 Group - %VERSION%-1
- Initial RPM packaging
