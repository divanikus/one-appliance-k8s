# ---------------------------------------------------------------------------- #
# Copyright 2018-2019, OpenNebula Project, OpenNebula Systems                  #
#                                                                              #
# Licensed under the Apache License, Version 2.0 (the "License"); you may      #
# not use this file except in compliance with the License. You may obtain      #
# a copy of the License at                                                     #
#                                                                              #
# http://www.apache.org/licenses/LICENSE-2.0                                   #
#                                                                              #
# Unless required by applicable law or agreed to in writing, software          #
# distributed under the License is distributed on an "AS IS" BASIS,            #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.     #
# See the License for the specific language governing permissions and          #
# limitations under the License.                                               #
# ---------------------------------------------------------------------------- #

# Important notes #############################################################
#
# If 'ONEAPP_K8S_TOKEN' and 'ONEAPP_K8S_HASH' both are set then the appliance
# will try to join already existing kubernetes cluster and the connection is:
# 'ONEAPP_K8S_ADDRESS':'ONEAPP_K8S_PORT'
#
# In this case 'ONEAPP_K8S_ADDRESS' must be set!
#
# Otherwise the appliance will create a new master and initialize it to listen
# on: 'ONEAPP_K8S_ADDRESS':'ONEAPP_K8S_PORT'
#
# In the case that 'ONEAPP_K8S_ADDRESS' is not set it defaults to local ip
#
# That means:
# - in the case of worker node 'ONEAPP_K8S_ADDRESS' is remote address
# - in the case of master node 'ONEAPP_K8S_ADDRESS' is (should be) local address
#
# Important notes #############################################################


# List of contextualization parameters
ONE_SERVICE_PARAMS=(
    'ONEAPP_K8S_ADDRESS'            'configure' 'K8s master node address/network (CIDR subnet)'      'O|text'
    'ONEAPP_K8S_TOKEN'              'configure' 'K8s token (to join node into the cluster)'          'O|password'
    'ONEAPP_K8S_HASH'               'configure' 'K8s hash (to join node into the cluster)'           'O|text'
    'ONEAPP_K8S_NODENAME'           'configure' 'K8s master node name'                               'O|text'
    'ONEAPP_K8S_PORT'               'configure' 'K8s API port (default 6443)'                        'O|text'
    'ONEAPP_K8S_PODS_NETWORK'       'configure' 'K8s pods network in CIDR (default 10.244.0.0/16)'   'O|text'
    'ONEAPP_K8S_ADMIN_USERNAME'     'configure' 'UI dashboard admin account (default admin-user)'    'O|text'
)


### Appliance metadata ########################################################

ONE_SERVICE_NAME='Service Kubernetes - LXD'
ONE_SERVICE_VERSION=1.18
ONE_SERVICE_BUILD=$(date +%s)
ONE_SERVICE_SHORT_DESCRIPTION='Appliance with preinstalled Kubernetes for LXD hosts'
ONE_SERVICE_DESCRIPTION=$(cat <<EOF
Appliance with preinstalled Kubernetes. If you don't provide a token and a hash
the appliance will bootstrap in a single-node mode and the running instance will
be a master.

Initial configuration can be customized via parameters:

$(params2md 'configure')

In the case of a master the \`ONEAPP_K8S_ADDRESS\` variable determines the address
of the master, the network and the interface on which kubernetes communication will
take place. It can contain either a direct ip address, a subnet with a prefix or
a network address. The actual address will be derived from it. If you don't provide
any value then it will use the ip address on the default interface. The following
values are all valid examples:
\`\`\`
192.168.122.100
192.168.122.100/24
192.168.122.0/24
192.168.122.0
\`\`\`

\`ONEAPP_K8S_NODENAME\` is applicable to the master node only.

In the case that you want to add more nodes to the cluster you must provide all
of these for the node to successfully join:
\`ONEAPP_K8S_ADDRESS\` - which must be the ip of the master (the actual address)
\`ONEAPP_K8S_TOKEN\` - stored on the master in the \`/etc/one-appliance/config\`
\`ONEAPP_K8S_HASH\` - also on the master in the \`/etc/one-appliance/config\`

Created token never expires - so handle it carefully. If you would rather create
short-lived token then delete the current one and create new. You can find more
info here:
[documentation](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#join-nodes)

PODs communicate on a designated network defined by \`ONEAPP_K8S_PODS_NETWORK\` or
on \`10.244.0.0/16\` if not defined. More info here:
[documentation](https://docs.projectcalico.org/v3.6/getting-started/kubernetes/installation/flannel)

After the bootstrapping of the service you can either control the kubernetes
from within the instance via \`kubectl\` command or you can run \`kubectl\`
from another machine if you follow these steps:
\`\`\`
\$ scp root@<ONEAPP_K8S_ADDRESS>:/etc/kubernetes/admin.conf .
\$ kubectl --kubeconfig ./admin.conf get nodes
\`\`\`
EOF
)



### Contextualization defaults ################################################

ONEAPP_K8S_PORT="${ONEAPP_K8S_PORT:-6443}"
ONEAPP_K8S_PODS_NETWORK="${ONEAPP_K8S_PODS_NETWORK:-10.244.0.0/16}"
ONEAPP_K8S_ADMIN_USERNAME="${ONEAPP_K8S_ADMIN_USERNAME:-admin-user}"
ONEAPP_DOCKER_EDITION="${ONEAPP_DOCKER_EDITION:-docker-ce}" # docker-ee
ONEAPP_DOCKER_VERSION=${ONEAPP_DOCKER_VERSION:-19.03}
ONEAPP_CALICO_VERSION=${ONEAPP_CALICO_VERSION:-3.13}
ONEAPP_ONEFLOW_MASTER_ROLE="${ONEAPP_ONEFLOW_MASTER_ROLE:-master}"
#ONEAPP_K8S_NODENAME
#ONEAPP_K8S_ADDRESS
#ONEAPP_DOCKER_EE_URL



### Globals ###################################################################

DEP_PKGS="coreutils openssh-server curl jq openssl ca-certificates apt-transport-https gnupg2 software-properties-common"
K8S_MANIFEST_DIR="${ONE_SERVICE_SETUP_DIR}/kubernetes/"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


#
# service implementation
#

service_cleanup()
{
    :
}

service_install()
{
    # packages
    install_pkgs ${DEP_PKGS}

    # docker
    install_docker "$ONEAPP_DOCKER_EDITION"
    stop_docker
    configure_docker
    start_docker
    disable_docker

    # kubernetes
    install_kubernetes
    start_kubernetes
    create_k8s_manifest_dir
    fetch_k8s_network_plugin
    fetch_k8s_dashboard
    fetch_k8s_images
    disable_kubernetes

    # service metadata
    create_one_service_metadata

    # cleanup
    postinstall_cleanup

    msg info "INSTALLATION FINISHED"

    return 0
}

service_configure()
{
    # stop services first
    stop_kubernetes
    stop_docker

    # docker
    configure_docker
    enable_docker
    start_docker

    # kubernetes
    configure_kubernetes
    enable_kubernetes
    start_kubernetes

    # store credentials
    report_config

    msg info "CONFIGURATION FINISHED"

    return 0
}

service_bootstrap()
{
    bootstrap_kubernetes

    msg info "BOOTSTRAP FINISHED"

    return 0
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


#
# functions
#

install_docker()
{
    _edition="$1"

    case "$_edition" in
        docker-ce)
            msg info "Installing Docker Community Edition (CE) repository"
            curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -

            add-apt-repository \
                "deb [arch=amd64] https://download.docker.com/linux/debian \
                $(lsb_release -cs) \
                stable"
            apt update
            ;;
        docker-ee)
            if [ -n "$ONEAPP_DOCKER_EE_URL" ] ; then
                msg info "Installing Docker Enterprise Edition (EE) repository"
                curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
                add-apt-repository \
                    "deb [arch=amd64] $ONEAPP_DOCKER_EE_URL/debian \
                    $(lsb_release -cs) \
                    stable"
                apt update
            else
                msg error "Missing Docker-EE URL: https://docs.docker.com/install/linux/docker-ee/centos/#find-your-docker-ee-repo-url"
                return 1
            fi
            ;;
        *)
            msg error "Bad Docker edition - should be: docker-ce or docker-ee"
            return 1
            ;;
    esac

    _version="$ONEAPP_DOCKER_VERSION"
    case "$_version" in
        ''|latest)
            _version=$(apt -a list "$_edition" | \
                apt_pkg_filter "$_edition" | \
                head -n 1)

            if [ -z "$_version" ] ; then
                msg error "Failed to detect the latest ${_edition} version"
                return 1
            fi
            ;;
        *)
            _version=$(apt -a list "$_edition" | \
                apt_pkg_filter "$_edition" "$_version" | \
                head -n 1)

            if [ -z "$_version" ] ; then
                msg error "Failed to find the '${ONEAPP_DOCKER_VERSION}' docker version"
                return 1
            fi
            ;;
    esac

    msg info "Installing '${_edition}-${_version}'"
    install_pkgs "${_edition}=${_version}" "${_edition}-cli=${_version}" "containerd.io"
    apt-mark hold "${_edition}" "${_edition}-cli" "containerd.io"
}

configure_docker()
{
    msg info "Configuring docker"
    mkdir -p /etc/docker
    mkdir -p /etc/systemd/system/docker.service.d
    cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
}

stop_docker()
{
    msg info "Stopping docker service"
    systemctl stop docker || true
}

start_docker()
{
    msg info "Starting docker service"
    systemctl daemon-reload
    systemctl start docker
}

disable_docker()
{
    msg info "Disabling docker service"
    systemctl disable docker
}

enable_docker()
{
    msg info "Enabling docker service"
    systemctl enable docker
}

install_kubernetes()
{
    msg info "Install kubernetes repo"
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    add-apt-repository \
        "deb https://apt.kubernetes.io/ \
        kubernetes-xenial \
        main"
    apt update
    _version="$ONE_SERVICE_VERSION"
    case "$_version" in
        ''|latest)
            _version=$(apt -a \
                list kubelet | \
                apt_pkg_filter kubelet | \
                head -n 1)

            if [ -z "$_version" ] ; then
                msg error "Failed to detect the latest kubernetes version"
                return 1
            fi

            ONE_SERVICE_VERSION="$_version"
            ;;
        *)
            _version=$(apt -a \
                list kubelet | \
                apt_pkg_filter kubelet "$_version" | \
                head -n 1)

            if [ -z "$_version" ] ; then
                msg error "Failed to find the '${ONE_SERVICE_VERSION}' kubernetes version"
                return 1
            fi

            ONE_SERVICE_VERSION="$_version"
            ;;
    esac

    msg info "Install kubernetes packages version: ${_version}"
    if apt install -y \
        kubelet=${_version} kubeadm=${_version} kubectl=${_version}
    then
        apt-mark hold kubelet kubeadm kubectl
    else
        msg error "Kubernetes packages installation failed"
        exit 1
    fi
}

create_k8s_manifest_dir()
{
    msg info "Create directory for kubernetes manifest files"
    mkdir -p "${K8S_MANIFEST_DIR}"
}

fetch_k8s_images()
{
    msg info "Pulling the Kubernetes images"
    kubeadm config images pull

    msg info "Pulling other images from manifests"
    for image in $(cat "${K8S_MANIFEST_DIR}"/* | awk '{if ($1 ~ /image:/) print $2;}') ; do
        docker pull "$image"
    done
}

fetch_k8s_network_plugin()
{
    msg info "Downloading Canal (Calico+flannel) manifest for CNI networking"
    curl -o "${K8S_MANIFEST_DIR}"/canal.yaml \
        https://docs.projectcalico.org/v${ONEAPP_CALICO_VERSION}/manifests/canal.yaml
}

fetch_k8s_dashboard()
{
    msg info "Downloading K8S UI dashboard manifest"
    curl -o "${K8S_MANIFEST_DIR}"/kubernetes-dashboard.yaml \
        https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
}

set_service_values()
{
    msg info "Storing credentials and cluster info into variables..."

    _K8S_MASTER="$ONEAPP_K8S_ADDRESS"
    _K8S_JOIN_COMMAND=$(print_join_cred command)
    _K8S_TOKEN=$(print_join_cred token)
    _K8S_HASH=$(print_join_cred hash)
    _K8S_UI_PROXY_URL='http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/'

    msg info "Waiting for UI dashboard secret.."
    _K8S_UI_LOGIN_TOKEN=$(print_ui_login_token)
}

check_onegate()
{
    # find the master id and if there are multiple of them, pick the one with the lowest number
    _onegate_master_id=$(onegate service show --json | \
        jq -cr '.SERVICE.roles[] | select(.name == "'"${ONEAPP_ONEFLOW_MASTER_ROLE}"'") | { id: .nodes[] | .vm_info.VM.ID } | .[]' | \
        sort -un | head -n 1 || true)

    if ! echo "$_onegate_master_id" | grep -q '^[0-9]\+$' ; then
        msg info "No OneFlow service master"
        return 0
    fi

    msg info "Try to load OneFlow service data..."

    ONEAPP_K8S_TOKEN=$(onegate vm show "$_onegate_master_id" --json | jq -cr ".VM.USER_TEMPLATE.ONEGATE_K8S_TOKEN" | sed '/^null$/d')
    ONEAPP_K8S_HASH=$(onegate vm show "$_onegate_master_id" --json | jq -cr ".VM.USER_TEMPLATE.ONEGATE_K8S_HASH" | sed '/^null$/d')
    if [ -n "$ONEAPP_K8S_TOKEN" ] && [ -n "$ONEAPP_K8S_HASH" ] ; then
        ONEAPP_K8S_ADDRESS=$(onegate vm show "$_onegate_master_id" --json | jq -cr ".VM.USER_TEMPLATE.ONEGATE_K8S_MASTER" | sed '/^null$/d')
        if [ -n "$ONEAPP_K8S_ADDRESS" ] ; then
            msg info "All OneFlow service values loaded"
        else
            msg warning "Missing OneFlow value for the master address"
        fi
    else
        msg info "No OneFlow service data"
    fi
}

setup_onegate()
{
    _onegate_master_id=$(onegate vm show --json | jq -cr ".VM.ID" || true)

    if ! echo "$_onegate_master_id" | grep -q '^[0-9]\+$' ; then
        msg info "No OneFlow support"
        return 0
    fi

    msg info "Set OneFlow service data..."

    msg info "OneFlow service value: ONEGATE_K8S_MASTER"
    onegate vm update --data ONEGATE_K8S_MASTER="$_K8S_MASTER"

    msg info "OneFlow service value: ONEGATE_K8S_TOKEN"
    onegate vm update --data ONEGATE_K8S_TOKEN="$_K8S_TOKEN"

    msg info "OneFlow service value: ONEGATE_K8S_HASH"
    onegate vm update --data ONEGATE_K8S_HASH="$_K8S_HASH"

    # onegate utility chokes on dashes, eg: "--option"
    #msg info "OneFlow service value: ONEGATE_K8S_JOIN_COMMAND"
    #onegate vm update --data ONEGATE_K8S_JOIN_COMMAND="$_K8S_JOIN_COMMAND"

    msg info "OneFlow service value: ONEGATE_K8S_UI_PROXY_URL"
    onegate vm update --data ONEGATE_K8S_UI_PROXY_URL="$_K8S_UI_PROXY_URL"

    msg info "OneFlow service value: ONEGATE_K8S_UI_LOGIN_TOKEN"
    onegate vm update --data ONEGATE_K8S_UI_LOGIN_TOKEN="$_K8S_UI_LOGIN_TOKEN"
}

configure_kubernetes()
{
    msg info "Enabling iptables routing for Kubernetes"
    cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    sysctl --system

    # this config is important for kubectl to work at all
    KUBECONFIG=/etc/kubernetes/admin.conf
    export KUBECONFIG

    # ask onegate for oneflow data
    msg info "Check OneGate for OneFlow service values"
    check_onegate

    # setup hostname if the hostname is just localhost
    if [ -n "$(generate_hostname)" ] ; then
        msg info "Assigned a new hostname for the node: $(hostname)"
    fi

    if [ -n "$ONEAPP_K8S_TOKEN" ] && [ -n "$ONEAPP_K8S_HASH" ] ; then
        msg info "This node will serve as a worker"

        if ! is_ipv4_address "$ONEAPP_K8S_ADDRESS" ; then
            msg error "You must provide the master node ip (got: '${ONEAPP_K8S_ADDRESS}')"
            return 1
        fi

        setup_worker
        msg info "Worker setup done"
    else
        msg info "This node will serve as a master"

        if [ -n "$ONEAPP_K8S_ADDRESS" ] ; then
            _master_ip=$(get_gw_ip "$ONEAPP_K8S_ADDRESS")
            if [ -z "$_master_ip" ] ; then
                msg error "Could not get kubernetes internal ip"
                msg error "Bad ip/cidr format: ${ONEAPP_K8S_ADDRESS}"
                exit 1
            fi

            ONEAPP_K8S_ADDRESS="$_master_ip"
        else
            ONEAPP_K8S_ADDRESS=$(get_local_ip)
        fi

        setup_master
        setup_kubectl
        set_service_values
        setup_onegate
        msg info "Master setup done"
    fi
}

stop_kubernetes()
{
    msg info "Stopping kubernetes service"
    systemctl stop kubelet || true
}

start_kubernetes()
{
    msg info "Starting kubernetes service"
    systemctl daemon-reload
    systemctl start kubelet
}

disable_kubernetes()
{
    msg info "Disabling kubernetes service"
    systemctl disable kubelet
}

enable_kubernetes()
{
    msg info "Enabling kubernetes service"
    systemctl enable kubelet
}

# print on stdout the join credentials
# arg: command|token|hash
print_join_cred()
{
    _arg="$1"
    _token=$(kubeadm token list | grep -vi ^TOKEN | awk '{print $1}')
    _hash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
        | openssl rsa -pubin -outform der 2>/dev/null \
        | openssl dgst -sha256 -hex | sed 's/^.* //')

    if [ -z "$_token" ] || [ -z "$_hash" ] ; then
        return 1
    fi

    case "$_arg" in
        ''|command)
            echo kubeadm join "${ONEAPP_K8S_ADDRESS}:${ONEAPP_K8S_PORT}" \
                --token "$_token" \
                --discovery-token-ca-cert-hash "sha256:${_hash}"
            ;;
        token)
            echo "$_token"
            ;;
        hash)
            echo "$_hash"
            ;;
    esac

}

print_ui_login_token()
{
    while [ -z "$_secret" ] ; do
        _secret=$(kubectl -n kube-system get secret \
            | grep "^${ONEAPP_K8S_ADMIN_USERNAME}-token" \
            | awk '{print $1}')
        sleep 1s
    done

    _token=$(kubectl -n kube-system describe secret "$_secret" \
        | awk '{if ($1 == "token:") print $2}')

    # let's test that the output was longer than 32 chars which is a good bet
    # that it really is a token and not a word - k8s use 800+ long tokens
    if echo "$_token" | grep -q '^[^[:space:]]\{32,\}$' ; then
        echo "$_token"
    else
        msg error "Failed to get a token for login to the UI dashboard"
        exit 1
    fi
}

create_service_account()
{
    cat > "${K8S_MANIFEST_DIR}"/kubernetes-service-account.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${ONEAPP_K8S_ADMIN_USERNAME}
  namespace: kube-system
EOF

    cat > "${K8S_MANIFEST_DIR}"/kubernetes-cluster-role.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${ONEAPP_K8S_ADMIN_USERNAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: ${ONEAPP_K8S_ADMIN_USERNAME}
  namespace: kube-system
EOF

    msg info "Creating the '${ONEAPP_K8S_ADMIN_USERNAME}' account"
    kubectl apply -f "${K8S_MANIFEST_DIR}"/kubernetes-service-account.yaml
    kubectl apply -f "${K8S_MANIFEST_DIR}"/kubernetes-cluster-role.yaml
}

setup_master()
{
    msg info "Setting up internal ip for kubernetes"
    msg info "Kubernetes master ip: ${ONEAPP_K8S_ADDRESS}"

    # forcing kubernetes to use interface with the advertised ip:
    # https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#using-internal-ips-in-your-cluster
    # https://github.com/kubernetes/kubeadm/issues/203
    cat > /etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=${ONEAPP_K8S_ADDRESS} --fail-swap-on=false
EOF

    # set master node name
    if [ -z "$ONEAPP_K8S_NODENAME" ] ; then
        ONEAPP_K8S_NODENAME=$(hostname)
    fi

    # kubernetes
    msg info "Create kubernetes master node: ${ONEAPP_K8S_NODENAME}"
    kubeadm init --apiserver-advertise-address "$ONEAPP_K8S_ADDRESS" \
        --apiserver-bind-port "$ONEAPP_K8S_PORT" \
        --node-name "$ONEAPP_K8S_NODENAME" \
        --pod-network-cidr="${ONEAPP_K8S_PODS_NETWORK}" \
        --skip-token-print --token-ttl 0 \
        --ignore-preflight-errors "FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,Swap"

    # pod network
    msg info "Installing Canal (Calico+flannel) manifest for pod networking"
    sed -i "s#10.244.0.0/16#${ONEAPP_K8S_PODS_NETWORK}#g" "${K8S_MANIFEST_DIR}"/canal.yaml
    sed -i 's#^\(\s*\)\(- name: FELIX_IPTABLESREFRESHINTERVAL\)#\1- name: FELIX_IPTABLESBACKEND\n\1  value: "NFT"\n\1\2#' "${K8S_MANIFEST_DIR}"/canal.yaml
    kubectl apply -f "${K8S_MANIFEST_DIR}"/canal.yaml

    # waiting for ready and healthy status of kubernetes
    wait_for_k8s

    msg info "Installing K8S's UI dashboard manifest"
    kubectl apply -f "${K8S_MANIFEST_DIR}"/kubernetes-dashboard.yaml

    # creates the admin user account to login to the dashboard
    create_service_account

    msg info "Enable scheduling pods on the master"
    kubectl taint nodes --all node-role.kubernetes.io/master-
}

setup_worker()
{
    msg info "Setting up internal ip for kubernetes"
    _internal_ip=$(get_gw_ip "${ONEAPP_K8S_ADDRESS}")

    if [ -z "$_internal_ip" ] ; then
        msg error "Could not identify the internal ip: ${ONEAPP_K8S_ADDRESS}"
        exit 1
    fi

    msg info "Kubernetes internal ip: ${_internal_ip}"

    # forcing kubernetes to use interface with the advertised ip:
    # https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#using-internal-ips-in-your-cluster
    # https://github.com/kubernetes/kubeadm/issues/203
    cat > /etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=${_internal_ip} --fail-swap-on=false
EOF

    # kubernetes
    msg info "Create kubernetes worker node: $(hostname)"
    msg info "Join the kubernetes cluster on: ${ONEAPP_K8S_ADDRESS}:${ONEAPP_K8S_PORT}"
    kubeadm join "${ONEAPP_K8S_ADDRESS}:${ONEAPP_K8S_PORT}" \
        --token "$ONEAPP_K8S_TOKEN" \
        --discovery-token-ca-cert-hash "sha256:${ONEAPP_K8S_HASH}" \
        --ignore-preflight-errors "FileContent--proc-sys-net-bridge-bridge-nf-call-iptables"
}

setup_kubectl()
{
    msg info "Setup kubectl config"
    mkdir -p /root/.kube
    cp -a /etc/kubernetes/admin.conf /root/.kube/config
    chown root:root /root/.kube/config
}

is_master_node()
{
    test -f /etc/kubernetes/admin.conf
}

wait_for_k8s()
{
    # kubectl works only on the master node - we don't have config on the worker
    if is_master_node ; then
        msg info "Wait for master node to be ready..."
        _ready=''
        while [ "$_ready" != Ready ] ; do
            _ready=$(LANG=C kubectl --kubeconfig=/etc/kubernetes/admin.conf \
                get nodes --no-headers | awk '{print $2}' | sort -u)
            sleep 1s
        done

        msg info "Wait for all components to start..."
        _healthy=''
        while [ "$_healthy" != Healthy ] ; do
            _healthy=$(LANG=C kubectl --kubeconfig=/etc/kubernetes/admin.conf \
                get componentstatus --no-headers | awk '{print $2}' | sort -u)
            sleep 1s
        done
    fi

    return 0
}

bootstrap_kubernetes()
{
    return 0
}

postinstall_cleanup()
{
    msg info "Delete cache and stored packages"
    apt autoclean -y
    apt clean cache
}

install_pkgs()
{
    msg info "Install required packages"
    if ! apt install -y "${@}" ; then
        msg error "Package(s) installation failed"
        exit 1
    fi
}

report_config()
{
    msg info "Credentials and config values are saved in: ${ONE_SERVICE_REPORT}"

    cat > "$ONE_SERVICE_REPORT" <<EOF
[Kubernetes]
k8s_connection = https://${ONEAPP_K8S_ADDRESS}:${ONEAPP_K8S_PORT}
EOF

    if is_master_node ; then
        msg info "Gathering info about this kubernetes cluster (tokens, hash)..."
        cat >> "$ONE_SERVICE_REPORT" <<EOF
k8s_master = ${_K8S_MASTER}
k8s_join_command = ${_K8S_JOIN_COMMAND}
k8s_token = ${_K8S_TOKEN}
k8s_hash = ${_K8S_HASH}
k8s_ui_proxy_url = ${_K8S_UI_PROXY_URL}
k8s_ui_login_token = ${_K8S_UI_LOGIN_TOKEN}
EOF
    fi

    chmod 600 "$ONE_SERVICE_REPORT"
}
