msg()
{
    msg_type="$1"
    shift

    case "$msg_type" in
        info)
            printf "INFO: $@\n"
            ;;
        debug)
            echo 'DEBUG:' "$@" >&2
            ;;
        warning)
            echo 'WARNING [!]:' "$@" >&2
            ;;
        error)
            echo 'ERROR [!!]:' "$@" >&2
            return 1
            ;;
        *)
            echo 'UNKNOWN [?!]:' "$@" >&2
            return 2
            ;;
    esac
    return 0
}

# arg: <length>
gen_password()
{
    pw_length="${1:-16}"
    new_pw=''

    while true ; do
        if which pwgen >/dev/null 2>&1 ; then
            new_pw=$(pwgen -s "${pw_length}" 1)
            break
        elif which openssl >/dev/null 2>&1 ; then
            new_pw="${new_pw}$(openssl rand -base64 ${pw_length} | tr -dc '[:alnum:]')"
        else
            new_pw="${new_pw}$(head /dev/urandom | tr -dc '[:alnum:]')"
        fi
        [ "$(echo $new_pw | wc -c)" -ge "$pw_length" ] && break
    done

    echo "$new_pw" | cut -c1-${pw_length}
}

# arg: <ipv4 address>
is_ipv4_address()
{
    echo "$1" | grep '^[0-9.]*$' | awk '
    BEGIN {
        FS = ".";
        octet = 0;
    }
    {
        for(i = 1; i <= NF; i++)
            if (($i >= 0) && ($i <= 255))
                octet++;
    }
    END {
        if (octet == 4)
            exit 0;
        else
            exit 1;
    }'
}

get_local_ip()
{
    extif=$(ip r | awk '{if ($1 == "default") print $5;}')
    local_ip=$(ip a show dev "$extif" | \
        awk '{if ($1 == "inet") print $2;}' | sed -e '/^127\./d' -e 's#/.*##')

    echo "${local_ip:-localhost}"
}

# returns ip of an interface which has route to ip/cidr from argument
#arg: <plain ipv4 or address in cidr format>
get_gw_ip()
{
    ip r g "$1" 2>/dev/null | awk '
        {
            for(i = 1; i <= NF; i++)
            {
                if ($i == "src")
                {
                    print $(i + 1);
                    exit 0;
                }
            }
        }
    '
}

# it will create a new hostname from an ip address, but only if the current one
# is just localhost and in that case it will also prints it on the stdout
generate_hostname()
{
    if [ "$(hostname -s)" = localhost ] ; then
        _new_hostname="onekube-ip-$(get_local_ip | tr '.' '-')".localdomain
        hostname "$_new_hostname"
        hostname > /etc/hostname
        hostname -s
    fi
}

# show default help based on the ONE_SERVICE_PARAMS
# service_help in appliance.sh may override this function
default_service_help()
{
    echo "USAGE: "

    for _command in 'help' 'install' 'configure' 'bootstrap'; do
        echo " $(basename "$0") ${_command}"

        case "${_command}" in
            help)       echo '  Prints this help' ;;
            install)    echo '  Installs service' ;;
            configure)  echo '  Configures service via contextualization or defaults' ;;
            bootstrap)  echo '  Bootstraps service via contextualization' ;;
        esac

        local _index=0
        while [ -n "${ONE_SERVICE_PARAMS[${_index}]}" ]; do
            local _name="${ONE_SERVICE_PARAMS[${_index}]}"
            local _type="${ONE_SERVICE_PARAMS[$((_index + 1))]}"
            local _desc="${ONE_SERVICE_PARAMS[$((_index + 2))]}"
            local _input="${ONE_SERVICE_PARAMS[$((_index + 3))]}"
            _index=$((_index + 4))

            if [ "${_command}" = "${_type}" ]; then
                if [ -z "${_input}" ]; then
                    echo -n '    '
                else
                    echo -n '  * '
                fi

                printf "%-25s - %s\n" "${_name}" "${_desc}"
            fi
        done

        echo
    done

    echo 'Note: (*) variables are provided to the user via USER_INPUTS'
}

#TODO: more or less duplicate to common.sh/service_help()
params2md()
{
    local _command=$1

    local _index=0
    local _count=0
    while [ -n "${ONE_SERVICE_PARAMS[${_index}]}" ]; do
        local _name="${ONE_SERVICE_PARAMS[${_index}]}"
        local _type="${ONE_SERVICE_PARAMS[$((_index + 1))]}"
        local _desc="${ONE_SERVICE_PARAMS[$((_index + 2))]}"
        local _input="${ONE_SERVICE_PARAMS[$((_index + 3))]}"
        _index=$((_index + 4))

        if [ "${_command}" = "${_type}" ] && [ -n "${_input}" ]; then
            printf '* `%s` - %s\n' "${_name}" "${_desc}"
            _count=$((_count + 1))
        fi
    done

    if [ "${_count}" -eq 0 ]; then
        echo '* none'
    fi
}

create_one_service_metadata()
{
    cat >"${ONE_SERVICE_METADATA}" <<EOF
---
name: "${ONE_SERVICE_NAME}"
version: "${ONE_SERVICE_VERSION}"
build: ${ONE_SERVICE_BUILD}
short_description: "${ONE_SERVICE_SHORT_DESCRIPTION}"
description: |
$(echo "${ONE_SERVICE_DESCRIPTION}" | sed -e 's/^\(.\)/  \1/')
EOF

}

# args: <pkg> [<version>]
# use in pipe with yum -y --showduplicates list <pkg>
# yum version follows these rules:
#   starting at the first colon (:) and up to the first hyphen (-)
# example:
#   3:18.09.1-3.el7 -> 18.09.1
yum_pkg_filter()
{
    _pkg="$1"
    _version="$2"

    awk -v pkg="$_pkg" '{if ($1 ~ "^" pkg) print $2;}' | \
    sed -e 's/^[^:]*://' -e 's/-.*//' | \
    if [ -n "$_version" ] ; then
        # only the correct versions
        awk -v version="$_version" '
        {
            if ($1 ~ "^" version)
                print $1;
        }'
    else
        cat
    fi
}
