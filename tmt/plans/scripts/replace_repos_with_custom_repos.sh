# Backup all repositories
if ls /etc/yum.repos.d/*.repo 1>/dev/null 2>&1; then
for file in /etc/yum.repos.d/*.repo; do
    mv "$file" "${file}.backup$(date +%Y%m%d%H%M%S)"
done
fi

# Add beaker-harness repository to install beakerlib
source /etc/os-release
OS_MAJOR_VERSION=${VERSION_ID/%[.]*/}
OS_VERSION_UNDERSCORE=$(echo ${VERSION_ID} | sed 's/\./_/g')
{
echo "[beaker-harness]"
echo "baseurl = ${BEAKERLIB_HARNESS_URL_NO_VER}${OS_MAJOR_VERSION}/"
echo "enabled = 1"
echo "gpgcheck = 0"
echo "name = Beaker harness"
echo "skip_if_unavailable = 1"
} > /etc/yum.repos.d/beaker-harness.repo

# Configure repositories for RHEL 7
# Extras is required to install the leapp package
if [ -n "${OS_MAJOR_VERSION}" ] && [ "${OS_MAJOR_VERSION}" -eq 7 ]; then
{
    echo "[rhel-7-server-extras-rpms]"
    echo "name=RHEL 7 Server Extras"
    echo "baseurl=${RHEL_7_9_EXTRAS_REPO_URL}"
    echo "enabled = 1"
    echo "gpgcheck=0"
    echo ""
    echo "[rhel]"
    echo "name=rhel"
    echo "baseurl=${RHEL_7_9_SERVER_REPO_URL}"
    echo "enabled = 1"
    echo "gpgcheck=0"
} > /etc/yum.repos.d/rhel${OS_MAJOR_VERSION}.repo
exit
fi

# Configure repositories for RHEL 8+
BASEOS_VAR="RHEL_${OS_VERSION_UNDERSCORE}_BASEOS_REPO_URL"
APPSTREAM_VAR="RHEL_${OS_VERSION_UNDERSCORE}_APPSTREAM_REPO_URL"

# Configure repositories on the control node running latest RHEL
# Control node is running latest RHEL 9 from CI, its repositories are set
# in variables in the form RHEL_9_LATEST_, no RHEL_X_Y
if [ -z "${!BASEOS_VAR}" ] && [ -z "${!APPSTREAM_VAR}" ]; then
BASEOS_VAR="RHEL_9_LATEST_BASEOS_REPO_URL"
APPSTREAM_VAR="RHEL_9_LATEST_APPSTREAM_REPO_URL"
elif [ -z "${!BASEOS_VAR}" ] || [ -z "${!APPSTREAM_VAR}" ]; then
echo "One of the repositories is not set:"
echo "BASEOS_VAR($BASEOS_VAR)=${!BASEOS_VAR}"
echo "APPSTREAM_VAR($APPSTREAM_VAR)=${!APPSTREAM_VAR}"
exit 1
fi
{
echo "[rhel-${OS_MAJOR_VERSION}-for-x86_64-baseos-rpms]"
echo "name=BaseOS for x86_64"
echo "baseurl=${!BASEOS_VAR}"
echo "enabled = 1"
echo "gpgcheck=0"
echo ""
echo "[rhel-${OS_MAJOR_VERSION}-for-x86_64-appstream-rpms]"
echo "name=AppStream for x86_64"
echo "baseurl=${!APPSTREAM_VAR}"
echo "enabled = 1"
echo "gpgcheck=0"
} > /etc/yum.repos.d/rhel${OS_MAJOR_VERSION}.repo
