#/bin/bash
#Author:Mikel
#Time:2019-09-28 06:22:57
#Name:scaffolding.sh
#Version:V1.0
#Description:This is a shell scripts for scaffolding

# Injection env
cat > /etc/profile.d/env.sh <<EOF
# os env
export HostName=
export SshKeyDir=

# mysql env
export MysqlUser=root
export MysqlPort=3306
export MysqlHost=127.0.0.1
export MysqlDbName=demo
export MysqlDbPwd=

# redis env

# rabbitmq env

# project env
export ProjectName=demo
export ServiceName=demo
export ProjectLogsDir=/var/logs/demo
EOF
source /etc/profile

#:<<Comments
#Comments

# init os
# init os function
init(){
    hostnamectl set-hostname `echo $HostName`
    ip_addr=`ip a | grep eth0 | grep inet | awk '{print $2}'|cut -d / -f1`
    echo $id_addr $HOSTNAME >> /etc/hosts
    ssh-keygen -t rsa
    for hostname in `cat /etc/hosts | sed '/dadi-saas/p' | awk '{print $2}'`
    do
        ssh-copy-id $hostname
    done 

    systemctl disable firewalld && systemctl stop firewalld
    sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config && setenforce 0
    swapoff -a yes | cp /etc/fstab /etc/fstab_bak
    cat /etc/fstab_bak | grep -v swap > /etc/fstab
    yum install -y chrony
    cp /etc/chrony.conf{,.bak}
    sed -i 's/^server/#&/' /etc/chrony.conf
    cat >> /etc/chrony.conf << EOF
    server 0.asia.pool.ntp.org iburst
    server 1.asia.pool.ntp.org iburst
    server 2.asia.pool.ntp.org iburst
    server 3.asia.pool.ntp.org iburst
EOF
    timedatectl set-timezone Asia/Shanghai
    systemctl enable chronyd && systemctl restart chronyd
    timedatectl && chronyc sources
    cat > /etc/sysconfig/modules/ipvs.modules <<EOF
    modprobe -- ip_vs
    modprobe -- ip_vs_rr
    modprobe -- ip_vs_wrr
    modprobe -- ip_vs_sh
    modprobe -- nf_conntrack_ipv4
EOF
    chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4
    yum install ipset ipvsadm -y
    cat > /etc/sysctl.d/k8s.conf <<EOF
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_nonlocal_bind = 1
    net.ipv4.ip_forward = 1
    vm.swappiness=0
EOF
    sysctl --system
}

#install docker
deploy_docker(){
    yum remove docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-selinux \
        docker-engine-selinux \
        docker-engine

    rm -rf /etc/systemd/system/docker.service.d
    rm -rf /var/lib/docker
    rm -rf /var/run/docker

    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager \
          --add-repo \
            http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    yum update -y && yum install -y docker-ce
    mkdir /etc/docker
    cat > /etc/docker/daemon.json <<EOF
    {
      "exec-opts": ["native.cgroupdriver=systemd"],
      "log-driver": "json-file",
      "data-root":"/var/lib/docker",
      "log-opts": {
        "max-size": "100m",
        "max-file": "3"
       },
      "storage-driver": "overlay2",
      "storage-opts": [
        "overlay2.override_kernel_check=true"
        #"overlay2.size=1G"
      ],
      "insecure-registries": [],
      "registry-mirrors": ["https://uyah70su.mirror.aliyuncs.com"]
    }
EOF

    mkdir -p /etc/systemd/system/docker.service.d
    cat > /usr/lib/systemd/system/docker.service <<EOF
    [Unit]
    Description=Docker Application Container Engine
    Documentation=https://docs.docker.com
    BindsTo=containerd.service
    After=network-online.target firewalld.service containerd.service
    Wants=network-online.target
    Requires=docker.socket

    [Service]
    Type=notify
    ExecStart=/usr/bin/dockerd
    ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT 
    ExecReload=/bin/kill -s HUP $MAINPID
    TimeoutSec=0
    RestartSec=2
    Restart=always
    StartLimitBurst=3
    StartLimitInterval=60s
    LimitNOFILE=infinity
    LimitNPROC=infinity
    LimitCORE=infinity
    TasksMax=infinity
    Delegate=yes
    KillMode=process

    [Install]
    WantedBy=multi-user.target
EOF
    systemctl enable docker
    systemctl start docker

    export DOCKER_COMPOSE_VERSION=1.25.0-rc2
    curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
}

# install kubeadm
deploy_kubeadm(){
    k8s_version=1.15.2
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
    enabled=1
    gpgcheck=1
    repo_gpgcheck=1
    gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    #安装kubeadm、kubelet、kubectl,注意这里默认安装当前最新版本v1.15.2:
    yum install -y kubeadm-$k8s_version kubelet-$k8s_version kubectl-$k8s_version
    systemctl enable kubelet && systemctl start kubelet
}

# init kuberneters master
init_kubernetes_master(){
    export InstallDir=/apps/install_k8s.sh
    [ -d "$InstallDir" ] || mkdir $InstalllDir
    kubeadm config print init-defaults > /$InstallDir/kubeadm-config.yaml 
    kubeadm init --config=kubeadm-config.yaml --experimental-upload-certs | tee $InstallDir/kubeadm-init.log
}

# init kubernetes node]
init_kubernetes_node(){
}

# clean kubernetes node
clean_kubernetes_node(){

}

# clean_kubernetes_master(){

}

# main function
main(){
    array=(init )
    select ch

}
