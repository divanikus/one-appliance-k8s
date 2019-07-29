# one-appliance-k8s
K8s appliance for OpenNebula

Based on official CentOS appliance, but updated to work with Debian Buster and LXD containers. 

Minimal setup for LXD (use it in a dedicated profile):

```
config:
  linux.kernel_modules: ip_tables,ip6_tables,netlink_diag,nf_nat,overlay,xt_conntrack
  raw.lxc: "lxc.apparmor.profile=unconfined\nlxc.cap.drop= \nlxc.cgroup.devices.allow=a\nlxc.mount.auto=proc:rw
    sys:rw"
  security.nesting: "true"
  security.privileged: "true"
description: K8s LXD profile for OpenNebula
devices:
  kmsg:
    path: /dev/kmsg
    source: /dev/kmsg
    type: unix-char
name: k8s
```
