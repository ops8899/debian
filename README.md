# debian
用于 Debian 系统的一组安装和配置脚本，帮助简化和自动化常用工具、服务以及环境的部署。适合系统管理员和 DevOps 工程师使用。
=======
# Debian 常用脚本使用手册

本手册包含一组适用于 Debian 12 的常用脚本，涵盖系统初始化、重新安装、代理配置、防火墙设置、网络管理等功能。以下是所有命令及其使用说明。

---

## **1. 系统初始化**

用于初始化 Debian 12 系统，安装必要工具并进行基础配置。

### **命令**
```bash
MIRROR="mirrors.aliyun.com"
SOURCES="/etc/apt/sources.list"

# 备份并生成新源
cp $SOURCES ${SOURCES}.bak
cat > $SOURCES << EOF
deb http://${MIRROR}/debian/ bookworm main contrib non-free non-free-firmware
deb http://${MIRROR}/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://${MIRROR}/debian/ bookworm-backports main contrib non-free non-free-firmware
deb http://${MIRROR}/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

export DEBIAN_FRONTEND=noninteractive
# 更新系统
apt-get update -q && apt-get dist-upgrade -y

which git >/dev/null 2>&1 || (apt update && apt install git -y)
rm -rf /debian && cd /
git clone https://github.com/ops8899/debian.git /debian
chmod +x -R /debian/
cd /debian/system
bash 1.sh -ssh-port 22 -cn  -ufw '80,443,53/udp,20000-30000,1.2.3.0/24' -ufw-domain 'ip.domain.com'

```

### **参数说明**
| 参数            | 说明                 | 示例                                   |
|---------------|----------------------|--------------------------------------|
| `-cn`         | 使用中国镜像源        | 无                                    |
| `-python`     | 安装 Python 环境      | 无                                    |
| `-ssh-port`   | 设置 SSH 端口号       | `-ssh-port 63333`                    |
| `-ufw`        | 开放的 TCP 端口范围   | `-p '80,443,53/udp,20000-30000,1.2.3.0/24'` |
| `-ufw-domain` | 设置域名 (txt 设置白名单 IP 列表)   | `'ip.domain.com'`                    |

---

## **2. 重新安装系统**

用于重新安装 Debian 12 系统。

### **命令**
```bash
which curl unzip >/dev/null 2>&1 || (apt update && apt install curl unzip -y) 
curl -s "https://raw.githubusercontent.com/ops8899/debian/refs/heads/main/system/cloud.sh" -o /tmp/cloud.sh
bash /tmp/cloud.sh -cn -ssh-port 61789 -pass Db8899

```

### **参数说明**
| 参数         | 说明                         | 示例                |
|--------------|------------------------------|-------------------|
| `-cn`        | 使用中国镜像源               | 无                 |
| `-ssh-port`  | 设置 SSH 端口号              | `-ssh-port 61789` |
| `-pass`      | 设置系统密码                 | `-pass Db8899`    |

---

## **3. 代理配置**

### **3.1 系统级代理**

为系统工具（如 `apt`、`curl`、`wget` 等）设置代理。

#### **命令**
```bash
# 设置代理
proxy-debian '代理地址'

# 清除代理
proxy-debian remove
```

---

### **3.2 Docker 代理**

为 Docker 设置代理。

#### **命令**
```bash
# 设置代理
proxy-docker '代理地址'

# 清除代理
proxy-docker remove

```

---

## **4. 防火墙配置**

通过脚本快速配置 UFW 防火墙规则。

### **命令**
```bash
ufw-set '80,443,53/udp,20000-30000,55000-55599,118.99.2.0/24,138.199.62.0/24,156.146.45.0/24' \
-txt 'ip.domain.com'
```

### **参数说明**
| 参数    | 说明                 | 示例                           |
|-------|----------------------|------------------------------|
|   | 开放的 TCP 端口范围   | `'80,443,20000-30000'`       |
|   | 开放的 UDP 端口范围   | `'53/udp,,500'`                |
|   | 白名单 IP        | `'1.2.3.0/24,5.6.7.0/24'`    |
| `-txt` | 设置域名 (txt 设置白名单 IP 列表) | `-d 'ip.domain.com'`         |

---

## **5. Docker 网络配置**

快速安装 Docker 并设置 Docker 网络。

### **命令**
```bash
docker-set '10.16.2.1' '10.16.2.0/24'
```

### **参数说明**
| 参数         | 说明             | 示例                |
|--------------|------------------|---------------------|
| `网关`       | Docker 网关地址 | `10.16.2.1`         |
| `子网`       | Docker 子网范围 | `10.16.2.0/24`      |

---

## **6. 管理工具**

以下是一些常用的管理脚本：

| 功能             | 命令示例                                            | 说明                       |
|------------------|-------------------------------------------------|----------------------------|
| 网络检查         | `net-check`                                     | 检查网络连通性             |
| 清理日志         | `cleanlog`                                      | 清理系统日志               |
| 服务器性能测试   | `bench`                                         | 测试服务器性能             |
| 清理路由规则     | `flushroute`                                    | 清空路由规则               |
| 代理检测         | `proxycheck 1.1.1.1:8080 socks5://1.1.1.1:1080` | 检测代理是否可用           |

---